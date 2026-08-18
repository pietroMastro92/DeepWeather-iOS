import SwiftUI

/// Dynamic Meteorological Authority / Civil Protection Provider based on location
enum AlertAuthorityProvider {
    static func authority(for countryName: String?) -> String {
        guard let country = countryName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !country.isEmpty else {
            return String(localized: "National Meteorological & Civil Protection Service")
        }

        if country.contains("italy") || country.contains("italia") {
            return String(localized: "Dipartimento della Protezione Civile / Servizio Meteorologico")
        } else if country.contains("united states") || country == "usa" || country == "us" {
            return "National Weather Service (NWS) / NOAA"
        } else if country.contains("united kingdom") || country == "uk" || country.contains("great britain") || country.contains("england") || country.contains("scotland") || country.contains("wales") {
            return "Met Office (UK)"
        } else if country.contains("france") || country.contains("francia") {
            return "Météo-France"
        } else if country.contains("germany") || country.contains("germania") || country.contains("deutschland") {
            return "Deutscher Wetterdienst (DWD)"
        } else if country.contains("spain") || country.contains("spagna") || country.contains("españa") {
            return "Agencia Estatal de Meteorología (AEMET)"
        } else if country.contains("japan") || country.contains("giappone") || country.contains("nippon") {
            return "Japan Meteorological Agency (JMA) / 気象庁"
        } else if country.contains("canada") {
            return "Environment and Climate Change Canada"
        } else if country.contains("australia") {
            return "Bureau of Meteorology (BOM)"
        } else if country.contains("switzerland") || country.contains("svizzera") || country.contains("suisse") {
            return "MeteoSwiss / Bundesamt für Meteorologie"
        } else if country.contains("austria") || country.contains("österreich") {
            return "GeoSphere Austria"
        } else {
            return String(localized: "National Meteorological & Civil Protection Service")
        }
    }
}

/// Official Meteorological Alert Model (Severe Weather System)
struct WeatherAlert: Identifiable, Sendable, Hashable {
    enum Severity: String, Sendable, Hashable {
        case warning  // Orange / Red Alert
        case advisory // Yellow Alert
        case info     // Informative Notice

        var color: Color {
            switch self {
            case .warning: return Color(red: 1.0, green: 0.45, blue: 0.15)
            case .advisory: return Color(red: 1.0, green: 0.80, blue: 0.20)
            case .info: return Color(red: 0.35, green: 0.75, blue: 1.0)
            }
        }

        var labelText: String {
            switch self {
            case .warning: return String(localized: "Orange warning")
            case .advisory: return String(localized: "Yellow advisory")
            case .info: return String(localized: "Advisory")
            }
        }
    }

    enum Category: String, Sendable, Hashable {
        case highHeat
        case extremeCold
        case strongWind
        case severeStorm
        case heavyRain

        var iconName: String {
            switch self {
            case .highHeat: return "thermometer.sun.fill"
            case .extremeCold: return "thermometer.snowflake"
            case .strongWind: return "wind"
            case .severeStorm: return "cloud.bolt.rain.fill"
            case .heavyRain: return "cloud.heavyrain.fill"
            }
        }
    }

    let id: String
    let severity: Severity
    let category: Category
    let headline: String
    let title: String
    let description: String
    let source: String
    let timeWindow: String

    /// Evaluates real-time weather response against meteorological thresholds dynamically
    static func detectAlerts(from weather: WeatherResponse?, useMetric: Bool = true) -> [WeatherAlert] {
        guard let weather else { return [] }
        var alerts: [WeatherAlert] = []

        let current = weather.currentCondition?.first
        let today = weather.weather?.first
        let hourly = today?.hourly ?? []

        let tempC = current?.tempC.flatMap(Double.init) ?? 20.0
        let maxTempC = today?.maxtempC.flatMap(Double.init) ?? tempC
        let minTempC = today?.mintempC.flatMap(Double.init) ?? tempC
        let feelsLikeC = current?.feelsLikeC.flatMap(Double.init) ?? tempC
        let windKmph = current?.windspeedKmph.flatMap(Double.init) ?? 0.0
        let maxWindKmph = max(windKmph, hourly.compactMap { $0.windspeedKmph.flatMap(Double.init) }.max() ?? 0.0)
        let maxRainChance = hourly.compactMap { $0.chanceofrain.flatMap(Int.init) }.max() ?? 0
        let weatherCode = current?.weatherCode.flatMap(Int.init) ?? 113

        let countryName = weather.nearestArea?.first?.country?.first?.value
        let sourceTitle = AlertAuthorityProvider.authority(for: countryName)
        let todayTitle = today?.date ?? String(localized: "today")

        // 1. High Heat Alert (Temperature Elevate / Heatwave)
        if maxTempC >= 33.0 || feelsLikeC >= 35.0 {
            let isExtreme = maxTempC >= 38.0 || feelsLikeC >= 40.0
            let maxTDisplay = useMetric ? "\(Int(round(maxTempC)))°C" : "\(Int(round(maxTempC * 9/5 + 32)))°F"
            let severity: Severity = isExtreme ? .warning : .advisory
            let sevText = isExtreme ? String(localized: "Orange heatwave warning") : String(localized: "Yellow high temperature advisory")

            alerts.append(WeatherAlert(
                id: "heat-\(todayTitle)",
                severity: severity,
                category: .highHeat,
                headline: String(localized: "Severe weather"),
                title: sevText,
                description: String(localized: "Expected maximum temperatures up to \(maxTDisplay) with high bioclimatic stress. Avoid exposure during peak hours and stay hydrated."),
                source: sourceTitle,
                timeWindow: String(localized: "Conditions expected throughout the day")
            ))
        }

        // 2. Extreme Cold & Freeze Alert (Temperature Molto Basse / Gelo)
        if minTempC <= 0.0 || feelsLikeC <= -2.0 {
            let isExtreme = minTempC <= -6.0 || feelsLikeC <= -8.0
            let minTDisplay = useMetric ? "\(Int(round(minTempC)))°C" : "\(Int(round(minTempC * 9/5 + 32)))°F"
            let severity: Severity = isExtreme ? .warning : .advisory
            let sevText = isExtreme ? String(localized: "Orange intense freeze warning") : String(localized: "Yellow freeze & frost advisory")

            alerts.append(WeatherAlert(
                id: "cold-\(todayTitle)",
                severity: severity,
                category: .extremeCold,
                headline: String(localized: "Severe weather"),
                title: sevText,
                description: String(localized: "Expected minimum temperatures down to \(minTDisplay) with frost and ground icing risk. Exercise extreme caution while driving."),
                source: sourceTitle,
                timeWindow: String(localized: "Conditions expected overnight and early morning")
            ))
        }

        // 3. Strong Wind Alert (Venti Forti / Burrasca)
        if maxWindKmph >= 45.0 {
            let isGale = maxWindKmph >= 70.0
            let windDisplay = useMetric ? "\(Int(round(maxWindKmph))) km/h" : "\(Int(round(maxWindKmph * 0.621371))) mph"
            let severity: Severity = isGale ? .warning : .advisory
            let sevText = isGale ? String(localized: "Orange severe gale warning") : String(localized: "Yellow strong wind advisory")

            alerts.append(WeatherAlert(
                id: "wind-\(todayTitle)",
                severity: severity,
                category: .strongWind,
                headline: String(localized: "Severe weather"),
                title: sevText,
                description: String(localized: "Expected wind gusts up to \(windDisplay) with possible disruption to travel and rough seas."),
                source: sourceTitle,
                timeWindow: String(localized: "Conditions expected in the coming hours")
            ))
        }

        // 4. Severe Storm Alert (Rischio Temporali e Grandine)
        let stormCodes = [200, 386, 389, 392, 395]
        if stormCodes.contains(weatherCode) || (maxRainChance >= 75 && (weatherCode == 299 || weatherCode == 302 || weatherCode == 305 || weatherCode == 308)) {
            let isHeavyStorm = stormCodes.contains(weatherCode)
            let severity: Severity = isHeavyStorm ? .warning : .advisory
            let sevText = isHeavyStorm ? String(localized: "Orange severe storm warning") : String(localized: "Yellow storm risk advisory")

            alerts.append(WeatherAlert(
                id: "storm-\(todayTitle)",
                severity: severity,
                category: .severeStorm,
                headline: String(localized: "Severe weather"),
                title: sevText,
                description: String(localized: "Thunderstorms expected with possible frequent lightning, localized hail and intense rain showers."),
                source: sourceTitle,
                timeWindow: String(localized: "Conditions expected until event concludes")
            ))
        }

        return alerts
    }
}
