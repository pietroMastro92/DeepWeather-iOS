import SwiftUI
import Charts

/// Modern Apple Liquid Glass Precipitation Chart
struct PrecipitationChartView: View {
    let points: [WeatherStore.ChartPoint]
    let midnights: [Date]
    var accent: Color = .cyan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Card Header
            HStack(spacing: 6) {
                Image(systemName: "drop.degreesign.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.cyan)

                Text(String(localized: "PRECIPITATION CHANCE"))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()
            }

            Divider()
                .overlay(.white.opacity(0.15))

            Chart(points) { point in
                BarMark(
                    x: .value("Time", point.date),
                    y: .value("Chance", point.precipChance)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [accent.opacity(0.85), accent.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.white.opacity(0.10))
                    AxisValueLabel {
                        if let intVal = value.as(Int.self) {
                            Text("\(intVal)%")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: midnights) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.15))
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .frame(height: 75)
        }
    }
}
