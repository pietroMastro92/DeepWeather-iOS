import Foundation

// MARK: - Root

struct WeatherResponse: Codable {
    let currentCondition: [CurrentCondition]?
    let nearestArea: [NearestArea]?
    let weather: [DayForecast]?

    enum CodingKeys: String, CodingKey {
        case currentCondition = "current_condition"
        case nearestArea = "nearest_area"
        case weather
    }
}

struct TextValue: Codable {
    let value: String?
}

// MARK: - Current

struct CurrentCondition: Codable {
    let tempC: String?
    let tempF: String?
    let feelsLikeC: String?
    let feelsLikeF: String?
    let humidity: String?
    let cloudcover: String?
    let pressure: String?
    let pressureInches: String?
    let uvIndex: String?
    let visibility: String?
    let visibilityMiles: String?
    let precipMM: String?
    let precipInches: String?
    let windspeedKmph: String?
    let windspeedMiles: String?
    let winddirDegree: String?
    let winddir16Point: String?
    let weatherCode: String?
    let observationTime: String?
    let weatherDesc: [TextValue]?

    enum CodingKeys: String, CodingKey {
        case tempC = "temp_C"
        case tempF = "temp_F"
        case feelsLikeC = "FeelsLikeC"
        case feelsLikeF = "FeelsLikeF"
        case humidity
        case cloudcover
        case pressure
        case pressureInches
        case uvIndex
        case visibility
        case visibilityMiles
        case precipMM
        case precipInches
        case windspeedKmph
        case windspeedMiles
        case winddirDegree
        case winddir16Point
        case weatherCode
        case observationTime = "observation_time"
        case weatherDesc
    }

    var conditionDescription: String {
        weatherDesc?.first?.value ?? "Unknown"
    }
}

// MARK: - Location

struct NearestArea: Codable {
    let areaName: [TextValue]?
    let country: [TextValue]?
    let region: [TextValue]?
    let latitude: String?
    let longitude: String?
}

// MARK: - Forecast

struct DayForecast: Codable {
    let date: String?
    let maxtempC: String?
    let mintempC: String?
    let maxtempF: String?
    let mintempF: String?
    let avgtempC: String?
    let avgtempF: String?
    let totalSnowCm: String?
    let sunHour: String?
    let uvIndex: String?
    let astronomy: [Astronomy]?
    let hourly: [HourlyForecast]?

    enum CodingKeys: String, CodingKey {
        case date
        case maxtempC
        case mintempC
        case maxtempF
        case mintempF
        case avgtempC
        case avgtempF
        case totalSnowCm = "totalSnow_cm"
        case sunHour
        case uvIndex
        case astronomy
        case hourly
    }
}

struct Astronomy: Codable {
    let sunrise: String?
    let sunset: String?
    let moonrise: String?
    let moonset: String?
    let moonPhase: String?
    let moonIllumination: String?

    enum CodingKeys: String, CodingKey {
        case sunrise
        case sunset
        case moonrise
        case moonset
        case moonPhase = "moon_phase"
        case moonIllumination = "moon_illumination"
    }
}

struct HourlyForecast: Codable {
    let time: String?
    let tempC: String?
    let tempF: String?
    let feelsLikeC: String?
    let feelsLikeF: String?
    let weatherCode: String?
    let weatherDesc: [TextValue]?
    let windspeedKmph: String?
    let windspeedMiles: String?
    let winddirDegree: String?
    let winddir16Point: String?
    let precipMM: String?
    let precipInches: String?
    let humidity: String?
    let cloudcover: String?
    let pressure: String?
    let uvIndex: String?
    let chanceofrain: String?
    let chanceofsnow: String?
    let chanceofsunshine: String?
    let visibility: String?

    enum CodingKeys: String, CodingKey {
        case time
        case tempC
        case tempF
        case feelsLikeC = "FeelsLikeC"
        case feelsLikeF = "FeelsLikeF"
        case weatherCode
        case weatherDesc
        case windspeedKmph
        case windspeedMiles
        case winddirDegree
        case winddir16Point
        case precipMM
        case precipInches
        case humidity
        case cloudcover
        case pressure
        case uvIndex
        case chanceofrain
        case chanceofsnow
        case chanceofsunshine
        case visibility
    }

    /// wttr.in encodes hours as "0", "300", "600", ... "2100".
    var hour: Int? {
        guard let time, let raw = Int(time) else { return nil }
        return raw / 100
    }

    var conditionDescription: String {
        weatherDesc?.first?.value ?? "Unknown"
    }
}
