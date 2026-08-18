import Foundation

/// Validates meteorological data for physical sanity and catches provider data corruption bugs (such as wttr.in issue #1290).
struct WeatherSanityValidator: Sendable {
    enum SanityResult: Sendable, Equatable {
        case valid
        case anomalous(reason: String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }

    /// Evaluates if a given WeatherResponse is meteorologically plausible.
    static func validate(
        _ response: WeatherResponse,
        latitude: Double? = nil,
        date: Date = Date()
    ) -> SanityResult {
        guard let current = response.currentCondition?.first else {
            return .anomalous(reason: "Missing current weather conditions.")
        }

        // 1. Temperature range bounds check (-80°C to 60°C)
        if let tempCStr = current.tempC, let tempC = Double(tempCStr) {
            if tempC < -80 || tempC > 60 {
                return .anomalous(reason: "Temperature \(tempC)°C is outside planetary physical limits.")
            }

            // 2. Mid-summer blizzard/heavy snow anomaly check (Issue #1290 detection)
            // wttr.in has a known bug returning -2°C Blizzard during Northern Hemisphere summer (June, July, August)
            let calendar = Calendar.current
            let month = calendar.component(.month, from: date)
            let isNorthernSummer = (6...8).contains(month)
            let isSouthernSummer = [12, 1, 2].contains(month)

            let isBlizzardOrSnowCode = ["227", "230", "323", "326", "329", "332", "335", "338", "368", "371", "392", "395"]
                .contains(current.weatherCode ?? "")

            let lat = latitude ?? 45.0 // Default to temperate zone if unknown
            if lat > 20.0 && isNorthernSummer && (tempC < 5.0 && isBlizzardOrSnowCode) {
                return .anomalous(reason: "Detected summer blizzard anomaly (Issue #1290): \(tempC)°C with code \(current.weatherCode ?? "") in month \(month).")
            }

            if lat < -20.0 && isSouthernSummer && (tempC < 5.0 && isBlizzardOrSnowCode) {
                return .anomalous(reason: "Detected southern summer blizzard anomaly: \(tempC)°C with code \(current.weatherCode ?? "") in month \(month).")
            }
        }

        return .valid
    }
}
