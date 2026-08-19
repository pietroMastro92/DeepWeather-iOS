import WidgetKit
import SwiftUI

// MARK: - Entry

struct DeepWeatherEntry: TimelineEntry {
    let date: Date
    let weather: WeatherResponse?
    let locationName: String?
    let useMetric: Bool
    let lastUpdated: Date?
}

// MARK: - Provider

struct DeepWeatherTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeepWeatherEntry {
        DeepWeatherEntry(date: Date(), weather: nil, locationName: nil, useMetric: true, lastUpdated: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeepWeatherEntry) -> Void) {
        completion(entry(from: WeatherSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeepWeatherEntry>) -> Void) {
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        let snapshot = WeatherSnapshot.load()
        completion(Timeline(entries: [entry(from: snapshot)], policy: .after(refreshDate)))
    }

    private func entry(from snapshot: WeatherSnapshot) -> DeepWeatherEntry {
        DeepWeatherEntry(
            date: Date(),
            weather: snapshot.weather,
            locationName: snapshot.locationName,
            useMetric: snapshot.useMetric,
            lastUpdated: snapshot.lastUpdated
        )
    }
}

// MARK: - Views

struct DeepWeatherWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeepWeatherEntry

    var body: some View {
        let style = Style(entry: entry)
        switch family {
        case .systemMedium:
            MediumWidgetView(style: style)
        case .accessoryCircular:
            CircularWidgetView(style: style)
        case .accessoryRectangular:
            RectangularWidgetView(style: style)
        case .accessoryInline:
            InlineWidgetView(style: style)
        default:
            SmallWidgetView(style: style)
        }
    }
}

// MARK: - System families

struct SmallWidgetView: View {
    let style: DeepWeatherWidgetEntryView.Style

    var body: some View {
        Group {
            if style.hasWeather {
                content
            } else {
                placeholder
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.62, blue: 0.95),
                    Color(red: 0.18, green: 0.42, blue: 0.83)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: style.icon)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
            Spacer()
            Text(style.tempText)
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundStyle(.white)
            Text(style.cityText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var placeholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.title2)
                .foregroundStyle(.white)
            Text("DeepWeather")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MediumWidgetView: View {
    let style: DeepWeatherWidgetEntryView.Style

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: style.icon)
                .font(.system(size: 38))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(style.conditionText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Text(minMaxText())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Text(style.cityText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Text(style.tempText)
                .font(.system(size: 40, weight: .light, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.35, green: 0.62, blue: 0.95),
                    Color(red: 0.18, green: 0.42, blue: 0.83)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func minMaxText() -> String {
        guard let day = style.entry.weather?.weather?.first else { return "" }
        let min = (style.entry.useMetric ? day.mintempC : day.mintempF) ?? "?"
        let max = (style.entry.useMetric ? day.maxtempC : day.maxtempF) ?? "?"
        return "\(String(localized: "High")) \(max)°  \(String(localized: "Low")) \(min)°"
    }
}

// MARK: - Lock Screen families

struct CircularWidgetView: View {
    let style: DeepWeatherWidgetEntryView.Style

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: style.icon)
                    .font(.caption)
                    .widgetAccentable()
                Text(style.tempText)
                    .font(.headline)
                    .widgetAccentable()
            }
        }
    }
}

struct RectangularWidgetView: View {
    let style: DeepWeatherWidgetEntryView.Style

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: style.icon)
                    .widgetAccentable()
                Text(style.tempText)
                    .font(.headline)
                    .widgetAccentable()
                Spacer()
                Text(style.cityText)
                    .font(.caption2)
                    .lineLimit(1)
            }
            Text(style.conditionText)
                .font(.caption)
                .lineLimit(1)
            Text(minMaxText())
                .font(.caption2)
        }
    }

    private func minMaxText() -> String {
        guard let day = style.entry.weather?.weather?.first else { return "" }
        let min = (style.entry.useMetric ? day.mintempC : day.mintempF) ?? "?"
        let max = (style.entry.useMetric ? day.maxtempC : day.maxtempF) ?? "?"
        return "\(String(localized: "High")) \(max)°  \(String(localized: "Low")) \(min)°"
    }
}

struct InlineWidgetView: View {
    let style: DeepWeatherWidgetEntryView.Style

    var body: some View {
        Text("\(style.tempText) \(style.conditionText) · \(style.cityText)")
    }
}

// MARK: - Shared style helper

extension DeepWeatherWidgetEntryView {
    struct Style {
        let entry: DeepWeatherEntry

        private var isDay: Bool {
            (6..<21).contains(Calendar.current.component(.hour, from: Date()))
        }

        var icon: String {
            WeatherIconMapper.symbol(for: entry.weather?.currentCondition?.first?.weatherCode, isDay: isDay)
        }

        var tempText: String {
            guard let c = entry.weather?.currentCondition?.first else { return "--°" }
            let value = entry.useMetric ? c.tempC : c.tempF
            return value.map { "\($0)°" } ?? "--°"
        }

        var conditionText: String {
            entry.weather?.currentCondition?.first?.conditionDescription ?? ""
        }

        var hasWeather: Bool {
            entry.weather != nil
        }

        var cityText: String {
            entry.locationName ?? String(localized: "Current location", comment: "Widget")
        }
    }
}

// MARK: - Widget & previews

struct DeepWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DeepWeatherWidget", provider: DeepWeatherTimelineProvider()) { entry in
            DeepWeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "DeepWeather"))
        .description(String(localized: "Current temperature and conditions."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct DeepWeatherWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeepWeatherWidget()
    }
}
