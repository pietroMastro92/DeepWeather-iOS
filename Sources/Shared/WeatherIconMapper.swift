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
        case 116: return isDay ? "cloud.sun" : "moon.cloud"
        case 119: return "cloud"
        case 122: return "cloud.fill"
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
