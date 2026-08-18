import SwiftUI

/// Chromatic theme derived from the current weather conditions and time of day.
struct WeatherTheme {
    let heroGradient: [Color]
    let accent: Color
    let heroText: Color

    /// Maps wttr.in weather codes (same groups as `WeatherIconMapper`)
    /// to a dynamic color theme.
    static func `for`(weatherCode: String?, isDay: Bool) -> WeatherTheme {
        guard let code = weatherCode.flatMap(Int.init) else {
            return isDay ? .partlyCloudy : .clearNight
        }
        switch code {
        case 113: return isDay ? .sunny : .clearNight
        case 116: return isDay ? .partlyCloudy : .partlyCloudyNight
        case 119, 122: return .cloudy
        case 143, 248, 260: return .foggy
        case 176, 185, 263, 266, 281, 284, 293, 296, 299, 302, 305, 308,
             311, 314, 317, 353, 356, 359, 362, 365, 374, 377: return .rainy
        case 179, 182, 227, 230, 320, 323, 326, 329, 332, 335, 338, 350,
             368, 371: return .snowy
        case 200, 386, 389, 392, 395: return .stormy
        default: return isDay ? .partlyCloudy : .clearNight
        }
    }
}

extension WeatherTheme {
    static let sunny = WeatherTheme(
        heroGradient: [
            Color(red: 0.18, green: 0.46, blue: 0.84),
            Color(red: 0.26, green: 0.56, blue: 0.90),
            Color(red: 0.38, green: 0.65, blue: 0.94)
        ],
        accent: Color(red: 1.0, green: 0.82, blue: 0.25),
        heroText: .white
    )

    static let clearNight = WeatherTheme(
        heroGradient: [
            Color(red: 0.10, green: 0.14, blue: 0.35),
            Color(red: 0.16, green: 0.22, blue: 0.48),
            Color(red: 0.22, green: 0.28, blue: 0.56)
        ],
        accent: Color(red: 0.65, green: 0.55, blue: 0.90),
        heroText: .white
    )

    static let partlyCloudy = WeatherTheme(
        heroGradient: [
            Color(red: 0.30, green: 0.56, blue: 0.86),
            Color(red: 0.42, green: 0.66, blue: 0.89),
            Color(red: 0.50, green: 0.70, blue: 0.91)
        ],
        accent: Color(red: 0.98, green: 0.75, blue: 0.25),
        heroText: .white
    )

    static let partlyCloudyNight = WeatherTheme(
        heroGradient: [
            Color(red: 0.15, green: 0.20, blue: 0.44),
            Color(red: 0.24, green: 0.28, blue: 0.52)
        ],
        accent: Color(red: 0.55, green: 0.50, blue: 0.85),
        heroText: .white
    )

    static let cloudy = WeatherTheme(
        heroGradient: [
            Color(red: 0.46, green: 0.54, blue: 0.66),
            Color(red: 0.52, green: 0.60, blue: 0.70),
            Color(red: 0.40, green: 0.48, blue: 0.60)
        ],
        accent: Color(red: 0.60, green: 0.70, blue: 0.82),
        heroText: .white
    )

    static let foggy = WeatherTheme(
        heroGradient: [
            Color(red: 0.62, green: 0.66, blue: 0.72),
            Color(red: 0.44, green: 0.49, blue: 0.58)
        ],
        accent: Color(red: 0.55, green: 0.58, blue: 0.65),
        heroText: .white
    )

    static let rainy = WeatherTheme(
        heroGradient: [
            Color(red: 0.38, green: 0.48, blue: 0.64),
            Color(red: 0.20, green: 0.28, blue: 0.46)
        ],
        accent: Color(red: 0.35, green: 0.55, blue: 0.80),
        heroText: .white
    )

    static let snowy = WeatherTheme(
        heroGradient: [
            Color(red: 0.45, green: 0.65, blue: 0.88),
            Color(red: 0.62, green: 0.78, blue: 0.94)
        ],
        accent: Color(red: 0.40, green: 0.62, blue: 0.88),
        heroText: .white
    )

    static let stormy = WeatherTheme(
        heroGradient: [
            Color(red: 0.38, green: 0.28, blue: 0.58),
            Color(red: 0.16, green: 0.18, blue: 0.26)
        ],
        accent: Color(red: 0.60, green: 0.45, blue: 0.80),
        heroText: .white
    )
}
