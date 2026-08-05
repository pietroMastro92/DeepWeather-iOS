import SwiftUI
import Charts

struct TemperatureChartView: View {
    let points: [WeatherStore.ChartPoint]
    let midnights: [Date]
    let now: Date
    let unitSymbol: String
    let observedTemp: Double?
    var accent: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Temperature (\(unitSymbol))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(points) { point in
                if let temperature = point.temperature {
                    AreaMark(
                        x: .value("Time", point.date),
                        y: .value("Temperature", temperature)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.28), accent.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .accessibilityHidden(true)

                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Temperature", temperature)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                if let first = points.first?.date, let last = points.last?.date,
                   now >= first, now <= last {
                    RuleMark(x: .value("Now", now))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .accessibilityHidden(true)

                    if let observedTemp {
                        PointMark(
                            x: .value("Time", now),
                            y: .value("Observed", observedTemp)
                        )
                        .foregroundStyle(accent)
                        .symbolSize(70)
                        .accessibilityLabel("Current temperature \(observedTemp, format: .number)")
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                AxisMarks(values: midnights) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .animation(.easeInOut(duration: 0.6), value: points.map(\.id))
            .frame(height: 110)
        }
    }
}
