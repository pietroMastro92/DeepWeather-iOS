import Foundation

/// Pure Swift astronomical moon phase and illumination engine.
/// Calculates accurate lunar age, phase name, illumination, and SF Symbol.
struct LunarPhaseEngine: Sendable {
    static let synodicMonth: Double = 29.53058867 // Mean length of lunar month in days

    /// Known reference New Moon date (Jan 11, 2024 at 11:57 UTC)
    private static let referenceNewMoon: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 11
        components.hour = 11
        components.minute = 57
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components) ?? Date(timeIntervalSince1970: 1704974220)
    }()

    struct MoonState: Sendable {
        let phaseName: String
        let phaseSymbol: String
        let illuminationPercent: Int
        let ageDays: Double
    }

    /// Returns the exact lunar phase in [0.0, 1.0)
    /// 0.0 = New Moon, 0.25 = First Quarter, 0.50 = Full Moon, 0.75 = Last Quarter
    static func phase(for date: Date = Date()) -> Double {
        let diffSeconds = date.timeIntervalSince(referenceNewMoon)
        let diffDays = diffSeconds / 86400.0
        var p = (diffDays.truncatingRemainder(dividingBy: synodicMonth)) / synodicMonth
        if p < 0 {
            p += 1.0
        }
        return p
    }

    /// Returns the illumination fraction [0.0, 1.0]
    static func illumination(for date: Date = Date()) -> Double {
        let p = phase(for: date)
        return (1.0 - cos(p * 2.0 * .pi)) / 2.0
    }

    /// Computes the normalized 3D Moon-to-Sun illumination direction vector
    /// based on the lunar phase and observer latitude (for hemisphere orientation).
    static func moonToSunDirection(for date: Date = Date(), latitude: Double = 45.0) -> (Float, Float, Float) {
        let p = phase(for: date)
        let angle = Float(p * 2.0 * .pi)

        // In Northern Hemisphere (lat >= 0), Waxing (0..0.5) is illuminated on Right (+X).
        // In Southern Hemisphere (lat < 0), the crescent orientation is inverted (-X).
        let hemisphereSign: Float = latitude < 0 ? -1.0 : 1.0

        let x = sin(angle) * hemisphereSign
        let y: Float = 0.05 * cos(angle) // Subtle orbital inclination
        let z = -cos(angle)

        let len = sqrt(x * x + y * y + z * z)
        return (x / len, y / len, z / len)
    }

    /// Computes the exact moon state for any given date.
    static func calculate(for date: Date = Date()) -> MoonState {
        let p = phase(for: date)
        let ageDays = p * synodicMonth
        let illum = illumination(for: date)
        let illuminationPercent = max(0, min(100, Int(round(illum * 100.0))))

        let (name, symbol) = phaseNameAndSymbol(for: p)

        return MoonState(
            phaseName: name,
            phaseSymbol: symbol,
            illuminationPercent: illuminationPercent,
            ageDays: ageDays
        )
    }

    private static func phaseNameAndSymbol(for phase: Double) -> (String, String) {
        // 8 distinct astronomical phases
        switch phase {
        case 0.0..<0.03:
            return ("New Moon", "moonphase.new.moon")
        case 0.03..<0.22:
            return ("Waxing Crescent", "moonphase.waxing.crescent")
        case 0.22..<0.28:
            return ("First Quarter", "moonphase.first.quarter")
        case 0.28..<0.47:
            return ("Waxing Gibbous", "moonphase.waxing.gibbous")
        case 0.47..<0.53:
            return ("Full Moon", "moonphase.full.moon")
        case 0.53..<0.72:
            return ("Waning Gibbous", "moonphase.waning.gibbous")
        case 0.72..<0.78:
            return ("Last Quarter", "moonphase.last.quarter")
        case 0.78..<0.97:
            return ("Waning Crescent", "moonphase.waning.crescent")
        default:
            return ("New Moon", "moonphase.new.moon")
        }
    }
}
