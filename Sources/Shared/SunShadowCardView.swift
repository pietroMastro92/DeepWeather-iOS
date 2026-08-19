import SwiftUI
import CoreLocation

// MARK: - Sun & Shadow Dashboard Card

/// Modern Liquid Glass dashboard card showcasing real-time solar position,
/// shadow cast bearing, length multiplier, and immediate sidewalk shade recommendations.
struct SunShadowCardView: View {
    let state: SolarShadowEngine.State
    var onOpenMap: () -> Void

    init(
        state: SolarShadowEngine.State,
        onOpenMap: @escaping () -> Void
    ) {
        self.state = state
        self.onOpenMap = onOpenMap
    }

    var body: some View {
        Button(action: onOpenMap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header Row
                HStack(alignment: .center) {
                    Label {
                        Text(String(localized: "Luce & Ombra"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                    } icon: {
                        Image(systemName: "sun.and.horizon.fill")
                            .foregroundStyle(.yellow)
                    }

                    Spacer()

                    // Shadow Quality Badge
                    HStack(spacing: 4) {
                        Image(systemName: state.shadowQuality.symbol)
                            .font(.caption2.weight(.bold))
                        Text(state.shadowQuality.shortTitle)
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.8))
                    .foregroundStyle(.white)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Main Content: Mini-Compass + Live Metrics
                HStack(spacing: 16) {
                    // Mini Solar & Shadow Compass Dial
                    MiniSolarCompassView(
                        sunAzimuth: state.solarPosition.azimuth,
                        shadowBearing: state.shadowProjection.bearing,
                        isDaylight: state.solarPosition.isDaylight
                    )
                    .frame(width: 76, height: 76)

                    // Metrics Breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        if state.solarPosition.isDaylight {
                            HStack(spacing: 12) {
                                MetricColumn(
                                    label: String(localized: "Elevazione"),
                                    value: String(format: "%.0f°", state.solarPosition.elevation),
                                    icon: "arrow.up.right"
                                )
                                MetricColumn(
                                    label: String(localized: "Rapporto Ombra"),
                                    value: state.shadowProjection.lengthMultiplier.map { String(format: "%.1f×", $0) } ?? "—",
                                    icon: "ruler"
                                )
                                MetricColumn(
                                    label: String(localized: "Direzione"),
                                    value: state.shadowProjection.bearingCompass,
                                    icon: "location.north.line.fill"
                                )
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "Sole sotto l'orizzonte"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                if let sunrise = state.milestones.sunrise {
                                    Text(String(localized: "Prossima alba: \(state.milestones.formattedSunrise)"))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.75))
                                }
                            }
                        }

                        // Walking sidewalk tip
                        HStack(spacing: 5) {
                            Image(systemName: "figure.walk")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.cyan)
                            Text(state.sidewalkShadeRecommendation)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                        }
                        .padding(.top, 2)
                    }
                }

                // Bottom Callout Strip
                HStack {
                    Text(String(localized: "Tocca per simulatore 24h e mappa 3D"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "map.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassCard(cornerRadius: 18, materialOpacity: 0.85)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                localized: "Mappa Luce e Ombra. Elevazione sole \(Int(state.solarPosition.elevation)) gradi, direzione ombra verso \(state.shadowProjection.bearingCompass). Tocca per aprire la mappa."
            )
        )
    }
}

// MARK: - Mini Solar Compass View

private struct MiniSolarCompassView: View {
    let sunAzimuth: Double
    let shadowBearing: Double
    let isDaylight: Bool

    var body: some View {
        ZStack {
            // Dial Background
            Circle()
                .fill(.ultraThinMaterial.opacity(0.6))
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1))

            // Cardinal Indicators
            VStack {
                Text("N")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("S")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(4)

            HStack {
                Text("O")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("E")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(4)

            if isDaylight {
                // Shadow Cast Beam (Dark / Cool Indigo Line)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.8), .indigo.opacity(0.1)],
                            startPoint: .center,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: 26)
                    .offset(y: -13)
                    .rotationEffect(.degrees(shadowBearing))

                // Sun Ray Beam (Golden Line)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange.opacity(0.2)],
                            startPoint: .center,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: 24)
                    .offset(y: -12)
                    .rotationEffect(.degrees(sunAzimuth))

                // Sun Orb Indicator
                Circle()
                    .fill(.yellow)
                    .frame(width: 10, height: 10)
                    .shadow(color: .yellow.opacity(0.9), radius: 4)
                    .offset(y: -28)
                    .rotationEffect(.degrees(sunAzimuth))

                // Shadow Obstacle Indicator
                Circle()
                    .fill(.indigo.opacity(0.9))
                    .frame(width: 8, height: 8)
                    .offset(y: -28)
                    .rotationEffect(.degrees(shadowBearing))
            } else {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.cyan.opacity(0.8))
            }

            // Center Pin
            Circle()
                .fill(.white)
                .frame(width: 5, height: 5)
        }
    }
}

// MARK: - Metric Column

private struct MetricColumn: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}
