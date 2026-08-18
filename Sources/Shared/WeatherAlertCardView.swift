import SwiftUI

/// Apple Weather-style "Meteo avverso" Civil Protection Alert Card
struct WeatherAlertCardView: View {
    let alerts: [WeatherAlert]

    @State private var showDetailSheet = false

    private var primaryAlert: WeatherAlert? {
        alerts.first
    }

    private var highestSeverityColor: Color {
        if alerts.contains(where: { $0.severity == .warning }) {
            return Color(red: 1.0, green: 0.45, blue: 0.15)
        }
        return Color(red: 1.0, green: 0.80, blue: 0.20)
    }

    var body: some View {
        if let primary = primaryAlert {
            Button {
                showDetailSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(highestSeverityColor)

                        Text(primary.headline)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    // Alert Summary Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(combinedAlertSummary)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        Text(primary.source)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.top, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.25, blue: 0.48).opacity(0.65))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    highestSeverityColor.opacity(0.65),
                                    .white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                }
                .shadow(color: highestSeverityColor.opacity(0.20), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDetailSheet) {
                WeatherAlertDetailSheet(alerts: alerts)
            }
        }
    }

    private var combinedAlertSummary: String {
        guard let first = alerts.first else { return "" }
        if alerts.count == 1 {
            return "\(first.title). \(first.timeWindow)."
        }
        let others = alerts.dropFirst().map(\.title).joined(separator: ", ")
        let additionalLabel = String(localized: "Additional alert: \(others)")
        return "\(first.title). \(first.timeWindow). \(additionalLabel)."
    }
}

// MARK: - Detailed Sheet for Full Civil Protection Advisory

private struct WeatherAlertDetailSheet: View {
    let alerts: [WeatherAlert]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(alerts) { alert in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: alert.category.iconName)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(alert.severity.color)

                                Text(alert.title)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                            }

                            Divider()
                                .overlay(.white.opacity(0.15))

                            Text(alert.description)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                                .lineSpacing(4)

                            HStack {
                                Label(alert.timeWindow, systemImage: "clock.fill")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.65))

                                Spacer()
                            }
                            .padding(.top, 4)

                            Text(String(localized: "Official source: \(alert.source)"))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(16)
                        .liquidGlassCard(cornerRadius: 16)
                    }
                }
                .padding(16)
            }
            .background {
                Color(red: 0.08, green: 0.12, blue: 0.22)
                    .ignoresSafeArea()
            }
            .navigationTitle(String(localized: "Official weather advisories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
