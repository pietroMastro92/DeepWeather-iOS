import Foundation

struct SavedLocation: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var detail: String
    var latitude: Double
    var longitude: Double
}

/// Legacy single-location payload from v1/v2 (no id), used for migration only.
private struct LegacySavedLocation: Codable {
    var name: String
    var detail: String
    var latitude: Double
    var longitude: Double
}

enum SavedLocationMigration {
    static func legacy(from data: Data) -> SavedLocation? {
        guard let legacy = try? JSONDecoder().decode(LegacySavedLocation.self, from: data) else {
            return nil
        }
        return SavedLocation(
            id: UUID().uuidString,
            name: legacy.name,
            detail: legacy.detail,
            latitude: legacy.latitude,
            longitude: legacy.longitude
        )
    }
}
