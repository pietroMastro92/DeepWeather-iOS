import Foundation

enum WeatherAnimationKind {
    case sun
    case moon
    case cloud
    case fog
    case rain
    case snow
    case storm
}

/// Maps WorldWeatherOnline weather codes (used by wttr.in) to SF Symbols.
enum WeatherIconMapper {
    static func symbol(for code: String?, isDay: Bool) -> String {
        guard let code, let value = Int(code) else { return "cloud.sun" }
        switch value {
        case 113: return isDay ? "sun.max" : "moon.stars"
        case 116: return isDay ? "cloud.sun" : "cloud.moon"
        case 119, 122: return "smoke.fill"
        case 143, 248, 260: return "cloud.fog"
        case 176, 263, 266, 281, 284, 293, 296: return "cloud.drizzle"
        case 299, 302, 305, 308, 353, 356, 359: return "cloud.rain"
        case 185, 311, 314, 317, 362, 365, 374, 377: return "cloud.sleet"
        case 179, 182, 323, 326, 329, 332, 335, 338, 350, 368, 371: return "cloud.snow"
        case 227, 230: return "wind.snow"
        case 200, 386, 389, 392, 395: return "cloud.bolt.rain"
        default: return "cloud.sun"
        }
    }

    /// Maps wttr.in moon phase names to SF Symbols (moonphase.*, SF Symbols 5).
    static func moonPhaseSymbol(for phase: String?) -> String {
        switch (phase ?? "").lowercased() {
        case "new moon": return "moonphase.new.moon"
        case "waxing crescent": return "moonphase.waxing.crescent"
        case "first quarter": return "moonphase.first.quarter"
        case "waxing gibbous": return "moonphase.waxing.gibbous"
        case "full moon": return "moonphase.full.moon"
        case "waning gibbous": return "moonphase.waning.gibbous"
        case "last quarter": return "moonphase.last.quarter"
        case "waning crescent": return "moonphase.waning.crescent"
        default: return "moon"
        }
    }

    /// Maps wttr.in moon phase names to localized titles.
    static func localizedMoonPhaseName(for phase: String?) -> String {
        switch (phase ?? "").lowercased() {
        case "new moon": return String(localized: "New Moon")
        case "waxing crescent": return String(localized: "Waxing Crescent")
        case "first quarter": return String(localized: "First Quarter")
        case "waxing gibbous": return String(localized: "Waxing Gibbous")
        case "full moon": return String(localized: "Full Moon")
        case "waning gibbous": return String(localized: "Waning Gibbous")
        case "last quarter": return String(localized: "Last Quarter")
        case "waning crescent": return String(localized: "Waning Crescent")
        default: return phase ?? "—"
        }
    }

    /// Maps weather codes to a continuous animation style for the hero icon.
    static func animationKind(for code: String?, isDay: Bool) -> WeatherAnimationKind {
        guard let code, let value = Int(code) else { return .cloud }
        switch value {
        case 113: return isDay ? .sun : .moon
        case 116: return isDay ? .cloud : .moon
        case 119, 122: return .cloud
        case 143, 248, 260: return .fog
        case 176, 185, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308,
             311, 314, 317, 353, 356, 359, 362, 365, 374, 377: return .rain
        case 179, 182, 227, 230, 320, 323, 326, 329, 332, 335, 338, 350,
             368, 371: return .snow
        case 200, 386, 389, 392, 395: return .storm
        default: return .cloud
        }
    }
}

/// Provides fully localized weather condition descriptions for iOS UI
enum WeatherConditionFormatter {
    static func localizedDescription(for code: String?, isDay: Bool, fallback: String? = nil) -> String {
        guard let code, let value = Int(code) else {
            return fallback ?? String(localized: "Partly cloudy")
        }
        switch value {
        case 113:
            return isDay ? String(localized: "Sunny") : String(localized: "Clear")
        case 116:
            return String(localized: "Partly cloudy")
        case 119:
            return String(localized: "Cloudy")
        case 122:
            return String(localized: "Overcast")
        case 143:
            return String(localized: "Mist")
        case 248, 260:
            return String(localized: "Fog")
        case 176, 263, 266, 293, 296:
            return String(localized: "Light rain")
        case 299, 302, 305, 308, 353, 356, 359:
            return String(localized: "Rain")
        case 185, 311, 314, 317, 362, 365, 374, 377:
            return String(localized: "Sleet")
        case 179, 182, 227, 230, 320, 323, 326, 329, 332, 335, 338, 350, 368, 371:
            return String(localized: "Snow")
        case 200, 386, 389, 392, 395:
            return String(localized: "Thunderstorm")
        default:
            return fallback ?? String(localized: "Partly cloudy")
        }
    }
}
