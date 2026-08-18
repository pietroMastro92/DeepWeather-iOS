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

    /// Computes the exact moon state for any given date.
    static func calculate(for date: Date = Date()) -> MoonState {
        let diffSeconds = date.timeIntervalSince(referenceNewMoon)
        let diffDays = diffSeconds / 86400.0

        // Calculate phase in [0.0, 1.0)
        var phase = (diffDays.truncatingRemainder(dividingBy: synodicMonth)) / synodicMonth
        if phase < 0 {
            phase += 1.0
        }

        let ageDays = phase * synodicMonth
        // Illumination: 0% at New Moon (0.0), 100% at Full Moon (0.5), 0% at New Moon (1.0)
        let illumination = (1.0 - cos(phase * 2.0 * .pi)) / 2.0
        let illuminationPercent = max(0, min(100, Int(round(illumination * 100.0))))

        let (name, symbol) = phaseNameAndSymbol(for: phase)

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
