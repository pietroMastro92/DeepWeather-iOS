import Foundation

enum WeatherProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto = "auto"
    case openMeteo = "openMeteo"
    case wttrIn = "wttrIn"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return String(localized: "Auto (Smart Fallback)")
        case .openMeteo:
            return String(localized: "Open-Meteo (Official Models)")
        case .wttrIn:
            return String(localized: "wttr.in (Classic)")
        }
    }

    var subtitle: String {
        switch self {
        case .auto:
            return String(localized: "Official models with anomaly protection & failover")
        case .openMeteo:
            return String(localized: "Direct European & global national meteorological services")
        case .wttrIn:
            return String(localized: "Community ASCII multi-source aggregator")
        }
    }
}

struct WeatherClient: Sendable {
    enum ClientError: LocalizedError {
        case invalidURL
        case badResponse
        case httpStatus(Int)
        case dataCorrupted(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "The location couldn't be turned into a valid request."
            case .badResponse: return "Unexpected response from weather service."
            case .httpStatus(let code): return "Weather service returned HTTP \(code)."
            case .dataCorrupted(let reason): return "Weather data rejected: \(reason)"
            }
        }
    }

    private let session: URLSession
    private let geocodingClient = GeocodingClient()

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Open-Meteo Fetching (3-Day Official Forecast)
    func fetchOpenMeteo(
        latitude: Double,
        longitude: Double,
        cityName: String? = nil,
        countryName: String? = nil
    ) async throws -> WeatherResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,cloud_cover,surface_pressure,pressure_msl,wind_speed_10m,wind_direction_10m,uv_index,visibility"),
            URLQueryItem(name: "hourly", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,wind_speed_10m,wind_direction_10m,uv_index,visibility,surface_pressure"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,precipitation_probability_max,uv_index_max,precipitation_sum,snowfall_sum"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "3")
        ]

        guard let url = components?.url else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("DeepWeather/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.httpStatus(http.statusCode)
        }

        let omResponse = try JSONDecoder().decode(OpenMeteoAdapter.OpenMeteoResponse.self, from: data)
        return OpenMeteoAdapter.adapt(omResponse, cityName: cityName, countryName: countryName)
    }

    // MARK: - wttr.in Fetching
    func fetchWttrIn(location: String?) async throws -> WeatherResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "wttr.in"
        if let location, !location.isEmpty {
            components.path = "/" + location
        }
        components.queryItems = [URLQueryItem(name: "format", value: "j1")]
        guard let url = components.url else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("DeepWeather/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.badResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(WeatherResponse.self, from: data)
    }

    // MARK: - Resilient Smart Fetch with Anomaly Protection & Fallback
    func fetch(
        location: String?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        cityName: String? = nil,
        countryName: String? = nil,
        provider: WeatherProvider = .auto
    ) async throws -> WeatherResponse {
        // Resolve coordinates if missing but a city or location name is provided
        var targetLat = latitude
        var targetLon = longitude
        var resolvedCity = cityName
        var resolvedCountry = countryName

        if (targetLat == nil || targetLon == nil), let searchName = (cityName ?? location), !searchName.isEmpty {
            if let firstGeo = try? await geocodingClient.search(searchName).first {
                targetLat = firstGeo.latitude
                targetLon = firstGeo.longitude
                if resolvedCity == nil { resolvedCity = firstGeo.name }
                if resolvedCountry == nil { resolvedCountry = firstGeo.country }
            }
        }

        // Fallback default coordinates if GPS has not yet emitted in simulator
        if targetLat == nil || targetLon == nil {
            targetLat = 41.8919 // Rome
            targetLon = 12.5113
            if resolvedCity == nil { resolvedCity = "Rome" }
            if resolvedCountry == nil { resolvedCountry = "Italy" }
        }

        switch provider {
        case .openMeteo, .auto:
            if let lat = targetLat, let lon = targetLon {
                let omResult = try await fetchOpenMeteo(latitude: lat, longitude: lon, cityName: resolvedCity, countryName: resolvedCountry)
                let sanity = WeatherSanityValidator.validate(omResult, latitude: lat)
                if sanity.isValid {
                    return omResult
                }
            }

            // If Open-Meteo sanity failed, try wttr.in as secondary
            let wttrResult = try await fetchWttrIn(location: location)
            let sanity = WeatherSanityValidator.validate(wttrResult, latitude: targetLat)
            if sanity.isValid {
                return wttrResult
            }
            // If wttr is also anomalous, return Open-Meteo as the most reliable
            if let lat = targetLat, let lon = targetLon {
                return try await fetchOpenMeteo(latitude: lat, longitude: lon, cityName: resolvedCity, countryName: resolvedCountry)
            }
            return wttrResult

        case .wttrIn:
            let response = try await fetchWttrIn(location: location)
            let sanity = WeatherSanityValidator.validate(response, latitude: targetLat)
            if !sanity.isValid {
                if let lat = targetLat, let lon = targetLon {
                    return try await fetchOpenMeteo(latitude: lat, longitude: lon, cityName: resolvedCity, countryName: resolvedCountry)
                }
            }
            return response
        }
    }
}
