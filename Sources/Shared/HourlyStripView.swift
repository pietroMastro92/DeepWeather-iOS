import SwiftUI

/// Modern Apple Liquid Glass Hourly Forecast Strip
struct HourlyStripView: View {
    let items: [WeatherStore.HourlyItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))

                Text(String(localized: "HOURLY FORECAST"))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()
            }

            Divider()
                .overlay(.white.opacity(0.15))

            // Horizontal Hourly Scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(items) { item in
                        HourlyItemColumn(item: item)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct HourlyItemColumn: View {
    let item: WeatherStore.HourlyItem
    @State private var isPressed = false

    private var isNow: Bool {
        item.hourText.lowercased() == "now" || item.hourText.lowercased() == "adesso"
    }

    var body: some View {
        VStack(spacing: 6) {
            // Hour Label
            Text(item.hourText)
                .font(.system(size: 13, weight: isNow ? .bold : .medium))
                .foregroundStyle(isNow ? .white : .white.opacity(0.75))

            // Weather Glyph
            Image(systemName: item.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(height: 22)
                .shadow(color: isNow ? .white.opacity(0.4) : .clear, radius: 4)

            // Rain Probability Badge
            Group {
                if item.precipChance >= 5 {
                    Text("\(item.precipChance)%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.cyan)
                } else {
                    Text(" ")
                        .font(.system(size: 10))
                }
            }
            .frame(height: 14)

            // Temperature
            Text(item.tempText)
                .font(.system(size: 16, weight: isNow ? .bold : .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            if isNow {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.8)
                    )
            }
        }
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
    }
}
