import SwiftUI

/// Modern Apple Liquid Glass Lunar Phases View
struct MoonPhaseView: View {
    let items: [WeatherStore.MoonItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Text(String(localized: "LUNAR PHASES"))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()
            }

            Divider()
                .overlay(.white.opacity(0.15))

            // 3-Day Moon Grid
            HStack(alignment: .top, spacing: 14) {
                ForEach(items) { item in
                    VStack(spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))

                        Image(systemName: item.phaseSymbol)
                            .font(.system(size: 26))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.3), radius: 6)
                            .frame(height: 30)

                        VStack(spacing: 2) {
                            Text(item.phaseName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text(item.illuminationText)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
