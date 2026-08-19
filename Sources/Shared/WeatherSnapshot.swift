import Foundation

/// Cached weather + settings shared between the app and its widgets
/// through the App Group container.
struct WeatherSnapshot: Codable {
    var weather: WeatherResponse?
    var lastUpdated: Date?
    var locationName: String?
    var locationDetail: String?
    var useMetric: Bool = (Locale.autoupdatingCurrent.measurementSystem != .us)
    var latitude: Double?
    var longitude: Double?
    var dailySummaryEnabled: Bool = false
    var dailySummaryHour: Int = 8
    var rainAlertEnabled: Bool = false

    /// Query location (GPS coordinates if known, otherwise automatic/IP).
    var locationString: String? {
        if let latitude, let longitude {
            return String(format: "%.5f,%.5f", latitude, longitude)
        }
        return nil
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> WeatherSnapshot {
        guard let data = defaults.data(forKey: AppGroup.snapshotKey) else {
            return WeatherSnapshot()
        }
        return (try? JSONDecoder().decode(WeatherSnapshot.self, from: data)) ?? WeatherSnapshot()
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: AppGroup.snapshotKey)
        }
    }
}
