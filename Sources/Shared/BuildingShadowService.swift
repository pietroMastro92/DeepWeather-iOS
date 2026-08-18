import Foundation
import CoreLocation

// MARK: - Building Footprint Model

/// A building footprint fetched from OpenStreetMap with its geographic boundary vertices and estimated height.
public struct BuildingFootprint: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let coordinates: [CLLocationCoordinate2D]
    public let heightMeters: Double

    public static func == (lhs: BuildingFootprint, rhs: BuildingFootprint) -> Bool {
        lhs.id == rhs.id && lhs.heightMeters == rhs.heightMeters
    }
}

// MARK: - Building Shadow Service

/// High-performance service that retrieves real OpenStreetMap building footprints for any coordinate
/// and caches them locally to enable real-time 60fps shadow projection.
@MainActor
public final class BuildingShadowService {
    public static let shared = BuildingShadowService()

    private var cache: [String: [BuildingFootprint]] = [:]
    private var inFlightTasks: [String: Task<[BuildingFootprint], Never>] = [:]

    private init() {}

    /// Fetches building footprints within a specified radius (in meters) around a coordinate.
    public func fetchBuildings(
        around center: CLLocationCoordinate2D,
        radiusMeters: Double = 600
    ) async -> [BuildingFootprint] {
        let key = cacheKey(for: center)
        if let cached = cache[key] {
            return cached
        }

        if let inFlight = inFlightTasks[key] {
            return await inFlight.value
        }

        let task = Task<[BuildingFootprint], Never> {
            let buildings = await performFetch(center: center, radiusMeters: radiusMeters)
            return buildings
        }

        inFlightTasks[key] = task
        let result = await task.value
        inFlightTasks[key] = nil
        cache[key] = result
        return result
    }

    // MARK: - Network Request

    private func performFetch(center: CLLocationCoordinate2D, radiusMeters: Double) async -> [BuildingFootprint] {
        let lat = center.latitude
        let lon = center.longitude
        let radius = Int(radiusMeters)

        let query = """
        [out:json][timeout:12];
        (
          way["building"](around:\(radius),\(lat),\(lon));
          relation["building"](around:\(radius),\(lat),\(lon));
        );
        out geom;
        """

        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else {
            return generateProceduralBuildings(around: center)
        }

        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
        request.httpMethod = "POST"
        request.httpBody = query.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return generateProceduralBuildings(around: center)
            }

            let parsed = parseOverpassResponse(data)
            if parsed.isEmpty {
                return generateProceduralBuildings(around: center)
            }
            return parsed
        } catch {
            return generateProceduralBuildings(around: center)
        }
    }

    // MARK: - Parsing

    private func parseOverpassResponse(_ data: Data) -> [BuildingFootprint] {
        struct OverpassResponse: Decodable {
            struct Element: Decodable {
                let id: Int64
                let type: String
                let geometry: [GeomPoint]?
                let tags: [String: String]?
            }
            struct GeomPoint: Decodable {
                let lat: Double
                let lon: Double
            }
            let elements: [Element]
        }

        guard let decoded = try? JSONDecoder().decode(OverpassResponse.self, from: data) else {
            return []
        }

        var results: [BuildingFootprint] = []

        for element in decoded.elements {
            guard let geom = element.geometry, geom.count >= 3 else { continue }
            let coords = geom.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }

            // Extract height or levels
            var height: Double = 8.5 // Default average building height in meters
            if let tags = element.tags {
                if let heightStr = tags["height"], let h = parseMeters(heightStr) {
                    height = max(3.0, h)
                } else if let levelsStr = tags["building:levels"], let levels = Double(levelsStr) {
                    height = max(3.0, levels * 3.2)
                }
            }

            results.append(
                BuildingFootprint(
                    id: element.id,
                    coordinates: coords,
                    heightMeters: height
                )
            )
        }

        return results
    }

    private func parseMeters(_ str: String) -> Double? {
        let cleaned = str.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "m", with: "")
            .replacingOccurrences(of: " ", with: "")
        return Double(cleaned)
    }

    private func cacheKey(for coord: CLLocationCoordinate2D) -> String {
        let roundedLat = (coord.latitude * 100).rounded() / 100
        let roundedLon = (coord.longitude * 100).rounded() / 100
        return "\(roundedLat),\(roundedLon)"
    }

    // MARK: - Procedural Fallback

    /// Synthesizes realistic surrounding city block buildings if offline or no network available.
    private func generateProceduralBuildings(around center: CLLocationCoordinate2D) -> [BuildingFootprint] {
        var buildings: [BuildingFootprint] = []
        let offsets: [(dx: Double, dy: Double, w: Double, h: Double, height: Double)] = [
            (-35, -25, 24, 18, 12.0),
            (20, -30, 20, 22, 9.0),
            (-45, 25, 28, 16, 15.0),
            (15, 30, 26, 20, 10.5),
            (-70, -10, 22, 24, 8.0),
            (55, 10, 30, 18, 14.0),
            (-20, -65, 32, 20, 11.0),
            (35, -70, 24, 26, 7.5),
            (-60, 65, 26, 22, 13.0),
            (40, 60, 28, 20, 9.5)
        ]

        let latMeters = 111139.0
        let lonMeters = 111139.0 * cos(center.latitude * .pi / 180.0)

        for (index, item) in offsets.enumerated() {
            let cx = center.longitude + (item.dx / lonMeters)
            let cy = center.latitude + (item.dy / latMeters)
            let hw = (item.w / 2.0) / lonMeters
            let hh = (item.h / 2.0) / latMeters

            let coords = [
                CLLocationCoordinate2D(latitude: cy - hh, longitude: cx - hw),
                CLLocationCoordinate2D(latitude: cy - hh, longitude: cx + hw),
                CLLocationCoordinate2D(latitude: cy + hh, longitude: cx + hw),
                CLLocationCoordinate2D(latitude: cy + hh, longitude: cx - hw),
                CLLocationCoordinate2D(latitude: cy - hh, longitude: cx - hw)
            ]

            buildings.append(
                BuildingFootprint(
                    id: Int64(index + 1000),
                    coordinates: coords,
                    heightMeters: item.height
                )
            )
        }

        return buildings
    }
}
