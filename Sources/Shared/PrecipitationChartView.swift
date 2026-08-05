import SwiftUI
import Charts

struct PrecipitationChartView: View {
    let points: [WeatherStore.ChartPoint]
    let midnights: [Date]
    var accent: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Precipitation")
                .font(.caption)
                .foregroundStyle(.secondary)

            Chart(points) { point in
                BarMark(
                    x: .value("Time", point.date),
                    y: .value("Chance", point.precipChance)
                )
                .foregroundStyle(accent.opacity(0.55))
                .cornerRadius(2)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: midnights) { _ in
                    AxisGridLine()
                }
            }
            .animation(.easeInOut(duration: 0.6), value: points.map(\.id))
            .frame(height: 45)
        }
    }
}
