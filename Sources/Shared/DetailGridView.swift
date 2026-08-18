import SwiftUI

/// Apple Weather-style Modular 2x2 Liquid Glass Detail Grid
struct DetailGridView: View {
    let items: [WeatherStore.DetailItem]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                ModularWeatherTile(item: item)
            }
        }
    }
}

private struct ModularWeatherTile: View {
    let item: WeatherStore.DetailItem
    @State private var isPressed = false

    private var iconColor: Color {
        switch item.id {
        case "uv":
            return .orange
        case "wind":
            return .teal
        case "humidity", "precipitation":
            return .cyan
        case "feels":
            return .indigo
        case "pressure":
            return .purple
        case "visibility":
            return .blue
        case "sunrise", "sunset":
            return .yellow
        case "moonrise", "moonset":
            return .white.opacity(0.85)
        default:
            return .white.opacity(0.8)
        }
    }

    private var contextualSubtitle: String {
        switch item.id {
        case "uv":
            let val = Int(item.value) ?? 0
            if val <= 2 { return String(localized: "Low for the rest of the day") }
            if val <= 5 { return String(localized: "Moderate risk") }
            if val <= 7 { return String(localized: "High protection required") }
            return String(localized: "Very high risk")
        case "humidity":
            return String(localized: "Moisture level in the air")
        case "wind":
            return String(localized: "Surface air currents")
        case "feels":
            return String(localized: "Perceived temperature")
        case "pressure":
            return String(localized: "Atmospheric pressure")
        case "visibility":
            return String(localized: "Distance of clear sight")
        case "precipitation":
            return String(localized: "Expected total")
        case "cloudcover":
            return String(localized: "Sky coverage")
        case "sunrise":
            return String(localized: "Morning solar rise")
        case "sunset":
            return String(localized: "Evening twilight")
        default:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: item.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(item.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            // Primary Metric Value
            Text(item.value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 2)

            // Subtitle Description
            if !contextualSubtitle.isEmpty {
                Text(contextualSubtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(minHeight: 120, alignment: .topLeading)
        .liquidGlassCard(cornerRadius: 18, materialOpacity: 0.85)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
    }
}
