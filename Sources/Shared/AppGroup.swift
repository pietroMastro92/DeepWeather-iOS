import Foundation

/// Shared identifiers between the app and its widgets (App Group).
enum AppGroup {
    static let id = "group.com.pietromastro.deepweather"
    static let snapshotKey = "weather.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}
