import Foundation
import CoreLocation

// MARK: - Shadow Polygon Model

/// A projected ground shadow polygon computed from a building footprint and solar position.
public struct ProjectedShadowPolygon: Identifiable, Sendable, Equatable {
    public let id: String
    public let coordinates: [CLLocationCoordinate2D]

    public static func == (lhs: ProjectedShadowPolygon, rhs: ProjectedShadowPolygon) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Building Shadow Geometry Generator

/// Mathematical engine that computes exact building shadow extrusion polygons.
public enum BuildingShadowGeometry {

    /// Projects all building footprints onto the ground along the current solar vector.
    public static func computeShadows(
        for buildings: [BuildingFootprint],
        solarPosition: SolarShadowEngine.SolarPosition
    ) -> [ProjectedShadowPolygon] {
        guard solarPosition.isDaylight, solarPosition.elevation > 0.5 else {
            return []
        }

        var shadows: [ProjectedShadowPolygon] = []
        let azimuthRad = solarPosition.azimuth * .pi / 180.0
        let elevationRad = solarPosition.elevation * .pi / 180.0
        let tanElevation = max(0.01, tan(elevationRad))

        // Shadow bearing is opposite of solar azimuth
        let shadowBearingDeg = (solarPosition.azimuth + 180.0).truncatingRemainder(dividingBy: 360.0)
        let shadowBearingRad = shadowBearingDeg * .pi / 180.0

        let latMeters = 111139.0

        for building in buildings {
            let coords = building.coordinates
            guard coords.count >= 3 else { continue }

            let centerLat = coords[0].latitude
            let lonMeters = max(1.0, latMeters * cos(centerLat * .pi / 180.0))

            // Shadow extrusion length (meters)
            let shadowLengthMeters = min(180.0, max(0.5, building.heightMeters / tanElevation))

            let deltaLat = (shadowLengthMeters * cos(shadowBearingRad)) / latMeters
            let deltaLon = (shadowLengthMeters * sin(shadowBearingRad)) / lonMeters

            // Generate extruded wall polygons & roof shadow
            var shadowVertices: [CLLocationCoordinate2D] = []

            // Extruded roof vertices
            let extrudedRoof = coords.map {
                CLLocationCoordinate2D(
                    latitude: $0.latitude + deltaLat,
                    longitude: $0.longitude + deltaLon
                )
            }

            // Create convex hull / boundary connecting ground base and extruded roof
            for i in 0..<(coords.count - 1) {
                let p1 = coords[i]
                let p2 = coords[i + 1]
                let p1Ext = extrudedRoof[i]
                let p2Ext = extrudedRoof[i + 1]

                // Normal of the wall edge (p1 -> p2)
                let edgeDx = (p2.longitude - p1.longitude) * lonMeters
                let edgeDy = (p2.latitude - p1.latitude) * latMeters
                let normalX = edgeDy
                let normalY = -edgeDx

                // Solar ray vector (from sun towards object)
                let sunRayX = sin(azimuthRad + .pi)
                let sunRayY = cos(azimuthRad + .pi)

                // If wall normal faces away from the sun, it casts a shadow quad
                let dot = normalX * sunRayX + normalY * sunRayY
                if dot >= -0.001 {
                    let quad = [p1, p2, p2Ext, p1Ext, p1]
                    shadows.append(
                        ProjectedShadowPolygon(
                            id: "shadow-\(building.id)-wall-\(i)",
                            coordinates: quad
                        )
                    )
                }
            }

            // Add the roof shadow polygon
            shadows.append(
                ProjectedShadowPolygon(
                    id: "shadow-\(building.id)-roof",
                    coordinates: extrudedRoof
                )
            )
        }

        return shadows
    }
}
