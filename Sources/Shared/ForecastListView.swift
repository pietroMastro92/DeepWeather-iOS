import SwiftUI

/// Modern Apple Liquid Glass Multi-Day Forecast with Temperature Range Bars
struct ForecastListView: View {
    let items: [WeatherStore.DayItem]
    var currentTemp: Double? = nil

    private var overallMin: Double {
        items.map(\.minValue).min() ?? 0
    }

    private var overallMax: Double {
        let maxVal = items.map(\.maxValue).max() ?? 100
        return maxVal == overallMin ? overallMin + 1 : maxVal
    }

    private var headerTitle: String {
        let count = items.count
        if count == 3 {
            return String(localized: "3-DAY FORECAST")
        }
        return String(localized: "\(count)-DAY FORECAST")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))

                Text(headerTitle)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()
            }

            Divider()
                .overlay(.white.opacity(0.15))

            // Forecast Rows
            VStack(spacing: 12) {
                ForEach(items) { day in
                    ForecastDayRow(
                        day: day,
                        overallMin: overallMin,
                        overallMax: overallMax,
                        currentTemp: currentTemp
                    )
                }
            }
        }
    }
}

private struct ForecastDayRow: View {
    let day: WeatherStore.DayItem
    let overallMin: Double
    let overallMax: Double
    let currentTemp: Double?

    var body: some View {
        HStack(spacing: 8) {
            // Day Name
            Text(day.title)
                .font(.system(size: 15, weight: day.isToday ? .bold : .medium))
                .foregroundStyle(day.isToday ? .white : .white.opacity(0.85))
                .frame(width: 50, alignment: .leading)

            // Weather Icon & Rain Chance Stack
            VStack(spacing: 2) {
                Image(systemName: day.symbol)
                    .renderingMode(.original)
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                    .frame(height: 20)

                if day.precipChance >= 5 {
                    Text("\(day.precipChance)%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.cyan)
                } else {
                    Text(" ")
                        .font(.system(size: 9))
                }
            }
            .frame(width: 36)

            // Min Temperature
            Text(day.minText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 32, alignment: .trailing)

            // Physical Temperature Color Range Bar
            TemperatureRangeBar(
                minValue: day.minValue,
                maxValue: day.maxValue,
                minTempC: day.minTempC,
                maxTempC: day.maxTempC,
                overallMin: overallMin,
                overallMax: overallMax,
                isToday: day.isToday,
                currentTemp: currentTemp
            )
            .frame(height: 4.5)

            // Max Temperature
            Text(day.maxText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Temperature Range Bar Component (Apple Weather Absolute Temperature Spectrum)

private struct TemperatureRangeBar: View {
    let minValue: Double
    let maxValue: Double
    let minTempC: Double
    let maxTempC: Double
    let overallMin: Double
    let overallMax: Double
    let isToday: Bool
    let currentTemp: Double?

    private var span: Double {
        max(1.0, overallMax - overallMin)
    }

    private var minRatio: Double {
        min(max(0.0, (minValue - overallMin) / span), 1.0)
    }

    private var maxRatio: Double {
        min(max(minRatio + 0.04, (maxValue - overallMin) / span), 1.0)
    }

    private var startColor: Color {
        Self.color(forCelsius: minTempC)
    }

    private var endColor: Color {
        Self.color(forCelsius: maxTempC)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let startX = width * minRatio
            let endX = width * maxRatio
            let barWidth = max(5.0, endX - startX)

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color.black.opacity(0.24))
                    .frame(height: 4.5)

                // Segment colored by actual physical temperature values
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [startColor, endColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: barWidth, height: 4.5)
                    .offset(x: startX)

                // Current Temperature Dot for Today
                if isToday, let current = currentTemp {
                    let currentRatio = min(max(0.0, (current - overallMin) / span), 1.0)
                    let dotX = min(max(startX + 2.5, width * currentRatio), endX - 2.5) - 3.0

                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 1.0)
                            )
                            .shadow(color: Color.black.opacity(0.4), radius: 1.5)
                    }
                    .offset(x: dotX)
                }
            }
        }
    }

    /// Apple Weather Standard Temperature-to-Color Spectrum
    static func color(forCelsius celsius: Double) -> Color {
        let stops: [(t: Double, r: Double, g: Double, b: Double)] = [
            (-15, 0.45, 0.35, 0.85), // Violet / Freezing
            (-5,  0.18, 0.48, 0.95), // Deep Blue
            (3,   0.24, 0.72, 0.95), // Sky Blue / Cyan
            (10,  0.28, 0.82, 0.68), // Mint / Teal
            (16,  0.48, 0.84, 0.38), // Spring Green
            (22,  0.96, 0.82, 0.22), // Amber / Warm Yellow
            (27,  0.98, 0.56, 0.16), // Warm Orange
            (34,  0.95, 0.30, 0.16), // Red-Orange
            (42,  0.88, 0.12, 0.22)  // Hot Crimson
        ]

        if celsius <= stops.first!.t {
            let f = stops.first!
            return Color(red: f.r, green: f.g, blue: f.b)
        }
        if celsius >= stops.last!.t {
            let l = stops.last!
            return Color(red: l.r, green: l.g, blue: l.b)
        }

        for i in 0..<(stops.count - 1) {
            let s0 = stops[i]
            let s1 = stops[i + 1]
            if celsius >= s0.t && celsius <= s1.t {
                let frac = (celsius - s0.t) / (s1.t - s0.t)
                let r = s0.r + frac * (s1.r - s0.r)
                let g = s0.g + frac * (s1.g - s0.g)
                let b = s0.b + frac * (s1.b - s0.b)
                return Color(red: r, green: g, blue: b)
            }
        }

        return Color(red: 0.98, green: 0.60, blue: 0.20)
    }
}
