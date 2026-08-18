import SwiftUI
import Charts

/// Interactive Apple Liquid Glass Temperature Chart with Native Non-Blocking Scrubbing
struct TemperatureChartView: View {
    let points: [WeatherStore.ChartPoint]
    let midnights: [Date]
    let now: Date
    let unitSymbol: String
    let observedTemp: Double?
    var accent: Color = .accentColor

    @State private var rawSelectedDate: Date?

    private var selectedPoint: WeatherStore.ChartPoint? {
        guard let rawSelectedDate else { return nil }
        return points.min(by: { abs($0.date.timeIntervalSince(rawSelectedDate)) < abs($1.date.timeIntervalSince(rawSelectedDate)) })
    }

    private var displayTemp: String {
        if let selected = selectedPoint, let temp = selected.temperature {
            return "\(Int(round(temp)))\(unitSymbol)"
        }
        if let observed = observedTemp {
            return "\(Int(round(observed)))\(unitSymbol)"
        }
        return "—"
    }

    private var displayTime: String {
        if let selected = selectedPoint {
            return selected.date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return String(localized: "Current Trend")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Card Header
            HStack(spacing: 6) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))

                Text(String(localized: "TEMPERATURE TREND"))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()

                // Interactive value preview
                HStack(spacing: 4) {
                    Text(displayTime)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    Text(displayTemp)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }

            Divider()
                .overlay(.white.opacity(0.15))

            // Swift Chart with native non-blocking X selection
            Chart {
                ForEach(points) { point in
                    if let temp = point.temperature {
                        AreaMark(
                            x: .value("Time", point.date),
                            y: .value("Temperature", temp)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.35),
                                    accent.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Temperature", temp)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                }

                // Current Time / Observed Indicator
                if let first = points.first?.date, let last = points.last?.date,
                   now >= first, now <= last {
                    RuleMark(x: .value("Now", now))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    if let observedTemp {
                        PointMark(
                            x: .value("Now", now),
                            y: .value("Observed", observedTemp)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(45)
                    }
                }

                // Interactive Selection Cursor
                if let selected = selectedPoint, let temp = selected.temperature {
                    RuleMark(x: .value("Selected", selected.date))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))

                    PointMark(
                        x: .value("Selected", selected.date),
                        y: .value("Temp", temp)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(70)
                }
            }
            .chartXSelection(value: $rawSelectedDate)
            .onChange(of: rawSelectedDate) { oldValue, newValue in
                if (oldValue == nil && newValue != nil) || (oldValue != nil && newValue != nil) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                        .foregroundStyle(.white.opacity(0.12))
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.6))
                        .font(.system(size: 10, design: .rounded))
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
            .frame(height: 125)
        }
    }
}
