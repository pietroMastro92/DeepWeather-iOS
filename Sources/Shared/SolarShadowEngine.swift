import Foundation
import CoreLocation

// MARK: - Solar & Shadow Engine

/// Pure Swift astronomical solar physics and shadow calculation engine.
/// Computes high-accuracy solar azimuth, elevation, shadow vectors, length ratios,
/// weather-modulated shadow sharpness, and street-level shade/sun guidance.
public struct SolarShadowEngine: Sendable {

    // MARK: - Types

    /// Represents the instantaneous solar position in the sky.
    public struct SolarPosition: Sendable, Equatable {
        /// Solar azimuth in degrees from True North (0° = North, 90° = East, 180° = South, 270° = West).
        public let azimuth: Double
        /// Solar altitude / elevation angle in degrees above the horizon (-90° to +90°).
        public let elevation: Double
        /// Solar zenith angle in degrees (90° - elevation).
        public let zenith: Double
        /// Solar declination in degrees.
        public let declination: Double
        /// Whether the sun is currently above the geometric horizon.
        public var isDaylight: Bool { elevation > 0 }
        /// Whether it is currently Golden Hour (elevation between 0° and 6°).
        public var isGoldenHour: Bool { elevation >= 0 && elevation <= 6.0 }
        /// Whether it is twilight (elevation between -6° and 0° civil twilight).
        public var isCivilTwilight: Bool { elevation >= -6.0 && elevation < 0 }
    }

    /// Represents the shadow cast characteristics for a given solar position.
    public struct ShadowProjection: Sendable, Equatable {
        /// Direction in degrees where shadows are cast (opposite to solar azimuth: `(azimuth + 180°) % 360°`).
        public let bearing: Double
        /// Cardinal / ordinal direction string for shadow bearing (e.g. "Nord-Est", "NE").
        public let bearingCompass: String
        /// Multiplier to calculate shadow length from obstacle height: `length = height * multiplier`.
        /// Multiplier = `1 / tan(elevation)`. Equal to `nil` when sun is below the horizon.
        public let lengthMultiplier: Double?
        /// Whether direct casting shadow is active (sun elevation > 0°).
        public let isDirectShadowActive: Bool

        /// Calculates the projected shadow length in meters for a given obstacle height in meters.
        public func shadowLength(forObstacleHeightMeters height: Double) -> Double? {
            guard let lengthMultiplier, isDirectShadowActive else { return nil }
            return max(0, height * lengthMultiplier)
        }
    }

    /// Quality / sharpness of shadows based on weather and cloud cover conditions.
    public enum ShadowQuality: Sendable, Equatable {
        case crisp      // ☀️ Direct, harsh sunlight with sharp defined shadows (Cloud cover < 20%)
        case diffuse    // ⛅ Filtered sunlight with soft diffuse shadows (Cloud cover 20%–65%)
        case ambient    // ☁️ Overcast/rainy diffuse ambient light, no cast shadow (Cloud cover > 65%)
        case night      // 🌙 Sun below horizon, moonlight/ambient only

        public var title: String {
            switch self {
            case .crisp: return String(localized: "Ombra Netta e Marcata")
            case .diffuse: return String(localized: "Ombra Morbida / Filtrata")
            case .ambient: return String(localized: "Luce Diffusa (Coperto)")
            case .night: return String(localized: "Notte (Nessuna Ombra)")
            }
        }

        public var shortTitle: String {
            switch self {
            case .crisp: return String(localized: "Netta")
            case .diffuse: return String(localized: "Morbida")
            case .ambient: return String(localized: "Assente")
            case .night: return String(localized: "Notte")
            }
        }

        public var symbol: String {
            switch self {
            case .crisp: return "sun.max.fill"
            case .diffuse: return "cloud.sun.fill"
            case .ambient: return "cloud.fill"
            case .night: return "moon.stars.fill"
            }
        }

        public var opacity: Double {
            switch self {
            case .crisp: return 0.85
            case .diffuse: return 0.45
            case .ambient: return 0.10
            case .night: return 0.0
            }
        }
    }

    /// Mode preference for navigation guidance.
    public enum NavigationIntent: String, CaseIterable, Identifiable, Sendable {
        case seekShade = "seek_shade" // Staying cool, avoiding high UV / heat
        case seekSun = "seek_sun"     // Enjoying sunshine, warming up, photography

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .seekShade: return String(localized: "Trova Ombra")
            case .seekSun: return String(localized: "Cerca Sole")
            }
        }

        public var icon: String {
            switch self {
            case .seekShade: return "tree.fill"
            case .seekSun: return "sun.max.fill"
            }
        }
    }

    /// Key astronomical solar milestones across the 24-hour day.
    public struct SolarDayMilestones: Sendable, Equatable {
        public let sunrise: Date?
        public let solarNoon: Date?
        public let sunset: Date?
        public let goldenHourMorningStart: Date?
        public let goldenHourMorningEnd: Date?
        public let goldenHourEveningStart: Date?
        public let goldenHourEveningEnd: Date?
        public let daylightDurationHours: Double?

        public var formattedSunrise: String {
            guard let sunrise else { return "--:--" }
            return Self.timeFormatter.string(from: sunrise)
        }

        public var formattedSunset: String {
            guard let sunset else { return "--:--" }
            return Self.timeFormatter.string(from: sunset)
        }

        public var formattedSolarNoon: String {
            guard let solarNoon else { return "--:--" }
            return Self.timeFormatter.string(from: solarNoon)
        }

        public var formattedDaylightDuration: String {
            guard let daylightDurationHours else { return "--" }
            let hours = Int(daylightDurationHours)
            let minutes = Int((daylightDurationHours - Double(hours)) * 60)
            return "\(hours)h \(minutes)m"
        }

        private static let timeFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return df
        }()
    }

    /// Comprehensive real-time solar and shadow snapshot for a location and time.
    public struct State: Sendable, Equatable {
        public let date: Date
        public let coordinate: CLLocationCoordinate2D
        public let solarPosition: SolarPosition
        public let shadowProjection: ShadowProjection
        public let shadowQuality: ShadowQuality
        public let milestones: SolarDayMilestones
        public let cloudCoverPercent: Int
        public let uvIndex: Int
        public let temperatureC: Double?

        /// Guidance text tailored to the user's intent (seek shade vs seek sun).
        public func guidance(for intent: NavigationIntent) -> String {
            guard solarPosition.isDaylight else {
                return String(localized: "Il sole è sotto l'orizzonte. Nessuna zona di ombra solare diretta attiva.")
            }

            let shadowCompass = shadowProjection.bearingCompass
            let sunCompass = SolarShadowEngine.compassPoint(for: solarPosition.azimuth)
            let ratioText = shadowProjection.lengthMultiplier.map { String(format: "%.1f×", $0) } ?? "-"

            switch shadowQuality {
            case .ambient:
                return String(localized: "Cielo coperto con luce diffusa. L'esposizione solare diretta è minima su tutti i lati.")
            case .diffuse, .crisp:
                if intent == .seekShade {
                    return String(
                        localized: "Il sole è a \(sunCompass) (\(Int(solarPosition.azimuth))°). Per muoverti all'ombra, cammina sul marciapiede a \(shadowCompass) (\(Int(shadowProjection.bearing))°), protetto dagli edifici (lunghezza ombra \(ratioText) altezza)."
                    )
                } else {
                    return String(
                        localized: "Il sole splende da \(sunCompass) (\(Int(solarPosition.azimuth))°). Per goderti la luce, scegli strade aperte orientate verso \(sunCompass) e cammina sul marciapiede esposto a Sud/Ovest."
                    )
                }
            case .night:
                return String(localized: "Notte: nessuna radiazione solare diretta.")
            }
        }

        /// Walking recommendation for street sidewalks.
        public var sidewalkShadeRecommendation: String {
            guard solarPosition.isDaylight else {
                return String(localized: "Nessuna ombra solare diretta")
            }
            let shadowDir = shadowProjection.bearingCompass
            return String(localized: "Lato \(shadowDir) in ombra")
        }

        /// Walking recommendation for street sidewalks in the sun.
        public var sidewalkSunRecommendation: String {
            guard solarPosition.isDaylight else {
                return String(localized: "Nessun irraggiamento solare")
            }
            let sunDir = SolarShadowEngine.compassPoint(for: solarPosition.azimuth)
            return String(localized: "Lato \(sunDir) al sole")
        }

        public static func == (lhs: State, rhs: State) -> Bool {
            lhs.date == rhs.date &&
            lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.solarPosition == rhs.solarPosition &&
            lhs.shadowProjection == rhs.shadowProjection &&
            lhs.shadowQuality == rhs.shadowQuality &&
            lhs.milestones == rhs.milestones &&
            lhs.cloudCoverPercent == rhs.cloudCoverPercent &&
            lhs.uvIndex == rhs.uvIndex &&
            lhs.temperatureC == rhs.temperatureC
        }
    }

    // MARK: - Core Astronomical Computations

    /// Calculates the instantaneous solar position for a coordinate and date.
    public static func solarPosition(
        coordinate: CLLocationCoordinate2D,
        date: Date = Date()
    ) -> SolarPosition {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // Julian Day calculation
        let jd = julianDate(from: date)
        let t = (jd - 2451545.0) / 36525.0 // Julian centuries since J2000.0

        // Geometric mean longitude of sun (degrees)
        var l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360.0)
        if l0 < 0 { l0 += 360.0 }

        // Mean anomaly of sun (degrees)
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let mRad = radians(m)

        // Sun equation of the center
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
                sin(2.0 * mRad) * (0.019993 - 0.000101 * t) +
                sin(3.0 * mRad) * 0.000289

        // Sun true longitude and apparent longitude (degrees)
        let trueLon = l0 + c
        let omega = 125.04 - 1934.136 * t
        let lambda = trueLon - 0.00569 - 0.00478 * sin(radians(omega))

        // Obliquity of ecliptic (degrees)
        let eps0 = 23.0 + (26.0 + (21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let eps = eps0 + 0.00256 * cos(radians(omega))

        // Sun declination (degrees)
        let sinDec = sin(radians(eps)) * sin(radians(lambda))
        let declination = degrees(asin(sinDec))

        // Equation of Time (minutes)
        let y = tan(radians(eps) / 2.0) * tan(radians(eps) / 2.0)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t) // Eccentricity
        let l0Rad = radians(l0)
        let eqTime = 4.0 * degrees(
            y * sin(2.0 * l0Rad) -
            2.0 * e * sin(mRad) +
            4.0 * e * y * sin(mRad) * cos(2.0 * l0Rad) -
            0.5 * y * y * sin(4.0 * l0Rad) -
            1.25 * e * e * sin(2.0 * mRad)
        )

        // UTC Time in minutes from midnight
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let timeMinutesUTC = Double(hour * 60 + minute) + Double(second) / 60.0

        // True Solar Time (TST) in minutes
        var tst = (timeMinutesUTC + eqTime + 4.0 * lon).truncatingRemainder(dividingBy: 1440.0)
        if tst < 0 { tst += 1440.0 }

        // Hour Angle (degrees)
        var hourAngle = (tst / 4.0) - 180.0
        if hourAngle < -180.0 { hourAngle += 360.0 }

        // Solar Zenith and Elevation
        let latRad = radians(lat)
        let decRad = radians(declination)
        let haRad = radians(hourAngle)

        let sinElevation = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        let clampedSinElev = max(-1.0, min(1.0, sinElevation))
        let unrefractedElevation = degrees(asin(clampedSinElev))

        // Atmospheric refraction correction for apparent visual elevation
        let refractionCorrection = atmosphericRefraction(elevationDeg: unrefractedElevation)
        let apparentElevation = unrefractedElevation + refractionCorrection
        let zenith = 90.0 - apparentElevation

        // Solar Azimuth (degrees from True North)
        let cosZenith = sin(radians(apparentElevation))
        let sinZenith = cos(radians(apparentElevation))

        var azimuth: Double = 180.0
        if sinZenith > 0.001 {
            let cosAzimuth = (sin(decRad) - sin(latRad) * cosZenith) / (cos(latRad) * sinZenith)
            let clampedCosAz = max(-1.0, min(1.0, cosAzimuth))
            let rawAz = degrees(acos(clampedCosAz))
            if hourAngle > 0 {
                azimuth = (360.0 - rawAz).truncatingRemainder(dividingBy: 360.0)
            } else {
                azimuth = rawAz.truncatingRemainder(dividingBy: 360.0)
            }
        }
        if azimuth < 0 { azimuth += 360.0 }

        return SolarPosition(
            azimuth: azimuth,
            elevation: apparentElevation,
            zenith: zenith,
            declination: declination
        )
    }

    /// Calculates the shadow projection vector and length multiplier for a solar position.
    public static func shadowProjection(for solarPos: SolarPosition) -> ShadowProjection {
        let shadowBearing = (solarPos.azimuth + 180.0).truncatingRemainder(dividingBy: 360.0)
        let compass = compassPoint(for: shadowBearing)

        let isDay = solarPos.elevation > 0
        let multiplier: Double?
        if isDay {
            let angleRad = radians(max(0.2, solarPos.elevation))
            multiplier = 1.0 / tan(angleRad)
        } else {
            multiplier = nil
        }

        return ShadowProjection(
            bearing: shadowBearing,
            bearingCompass: compass,
            lengthMultiplier: multiplier,
            isDirectShadowActive: isDay
        )
    }

    /// Determines shadow quality taking into account solar elevation and weather cloud cover.
    public static func shadowQuality(
        solarPos: SolarPosition,
        cloudCoverPercent: Int
    ) -> ShadowQuality {
        guard solarPos.elevation > 0 else {
            return .night
        }
        if cloudCoverPercent < 20 {
            return .crisp
        } else if cloudCoverPercent <= 65 {
            return .diffuse
        } else {
            return .ambient
        }
    }

    /// Calculates key solar milestones (Sunrise, Solar Noon, Sunset, Golden Hour) for a coordinate and date.
    public static func dayMilestones(
        coordinate: CLLocationCoordinate2D,
        date: Date = Date(),
        timeZone: TimeZone = .current
    ) -> SolarDayMilestones {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let startOfDay = calendar.startOfDay(for: date)
        guard let noonEstimate = calendar.date(byAdding: .hour, value: 12, to: startOfDay) else {
            return SolarDayMilestones(
                sunrise: nil,
                solarNoon: nil,
                sunset: nil,
                goldenHourMorningStart: nil,
                goldenHourMorningEnd: nil,
                goldenHourEveningStart: nil,
                goldenHourEveningEnd: nil,
                daylightDurationHours: nil
            )
        }

        let jd = julianDate(from: noonEstimate)
        let t = (jd - 2451545.0) / 36525.0

        var l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360.0)
        if l0 < 0 { l0 += 360.0 }
        let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
        let mRad = radians(m)
        let c = sin(mRad) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
                sin(2.0 * mRad) * (0.019993 - 0.000101 * t) +
                sin(3.0 * mRad) * 0.000289
        let trueLon = l0 + c
        let omega = 125.04 - 1934.136 * t
        let lambda = trueLon - 0.00569 - 0.00478 * sin(radians(omega))
        let eps0 = 23.0 + (26.0 + (21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
        let eps = eps0 + 0.00256 * cos(radians(omega))
        let declination = degrees(asin(sin(radians(eps)) * sin(radians(lambda))))

        let y = tan(radians(eps) / 2.0) * tan(radians(eps) / 2.0)
        let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let l0Rad = radians(l0)
        let eqTime = 4.0 * degrees(
            y * sin(2.0 * l0Rad) -
            2.0 * e * sin(mRad) +
            4.0 * e * y * sin(mRad) * cos(2.0 * l0Rad) -
            0.5 * y * y * sin(4.0 * l0Rad) -
            1.25 * e * e * sin(2.0 * mRad)
        )

        // Solar Noon in UTC minutes from midnight: 720 - 4*lon - eqTime
        let solarNoonUTCMinutes = 720.0 - (4.0 * coordinate.longitude) - eqTime
        let solarNoonDate = startOfDay.addingTimeInterval(solarNoonUTCMinutes * 60.0 - Double(timeZone.secondsFromGMT(for: date)))

        // Hour angle for standard sunrise/sunset (Zenith = 90.833° for atmospheric refraction and solar radius)
        let latRad = radians(coordinate.latitude)
        let decRad = radians(declination)
        let cosHA = (cos(radians(90.833)) - sin(latRad) * sin(decRad)) / (cos(latRad) * cos(decRad))

        var sunriseDate: Date? = nil
        var sunsetDate: Date? = nil
        var daylightHours: Double? = nil

        var goldenHourMorningStart: Date? = nil
        var goldenHourMorningEnd: Date? = nil
        var goldenHourEveningStart: Date? = nil
        var goldenHourEveningEnd: Date? = nil

        if cosHA >= -1.0 && cosHA <= 1.0 {
            let haDeg = degrees(acos(cosHA))
            let haMinutes = haDeg * 4.0

            let sunriseUTCMinutes = solarNoonUTCMinutes - haMinutes
            let sunsetUTCMinutes = solarNoonUTCMinutes + haMinutes

            sunriseDate = startOfDay.addingTimeInterval(sunriseUTCMinutes * 60.0 - Double(timeZone.secondsFromGMT(for: date)))
            sunsetDate = startOfDay.addingTimeInterval(sunsetUTCMinutes * 60.0 - Double(timeZone.secondsFromGMT(for: date)))
            daylightHours = (haMinutes * 2.0) / 60.0

            // Golden hour: elevation between 0° (or -0.833°) and 6° (Zenith 84° to 90.833°)
            let cosHAGolden = (cos(radians(84.0)) - sin(latRad) * sin(decRad)) / (cos(latRad) * cos(decRad))
            if cosHAGolden >= -1.0 && cosHAGolden <= 1.0 {
                let haGoldenDeg = degrees(acos(cosHAGolden))
                let haGoldenMin = haGoldenDeg * 4.0

                if let sunriseDate {
                    goldenHourMorningStart = sunriseDate
                    goldenHourMorningEnd = startOfDay.addingTimeInterval((solarNoonUTCMinutes - haGoldenMin) * 60.0 - Double(timeZone.secondsFromGMT(for: date)))
                }
                if let sunsetDate {
                    goldenHourEveningStart = startOfDay.addingTimeInterval((solarNoonUTCMinutes + haGoldenMin) * 60.0 - Double(timeZone.secondsFromGMT(for: date)))
                    goldenHourEveningEnd = sunsetDate
                }
            }
        } else if cosHA < -1.0 {
            // Midnight Sun (24h daylight)
            daylightHours = 24.0
        } else {
            // Polar Night (0h daylight)
            daylightHours = 0.0
        }

        return SolarDayMilestones(
            sunrise: sunriseDate,
            solarNoon: solarNoonDate,
            sunset: sunsetDate,
            goldenHourMorningStart: goldenHourMorningStart,
            goldenHourMorningEnd: goldenHourMorningEnd,
            goldenHourEveningStart: goldenHourEveningStart,
            goldenHourEveningEnd: goldenHourEveningEnd,
            daylightDurationHours: daylightHours
        )
    }

    /// Evaluates the complete State snapshot for a given coordinate, time, and weather parameters.
    public static func evaluate(
        coordinate: CLLocationCoordinate2D,
        date: Date = Date(),
        cloudCoverPercent: Int = 0,
        uvIndex: Int = 0,
        temperatureC: Double? = nil,
        timeZone: TimeZone = .current
    ) -> State {
        let solarPos = solarPosition(coordinate: coordinate, date: date)
        let shadow = shadowProjection(for: solarPos)
        let quality = shadowQuality(solarPos: solarPos, cloudCoverPercent: cloudCoverPercent)
        let milestones = dayMilestones(coordinate: coordinate, date: date, timeZone: timeZone)

        return State(
            date: date,
            coordinate: coordinate,
            solarPosition: solarPos,
            shadowProjection: shadow,
            shadowQuality: quality,
            milestones: milestones,
            cloudCoverPercent: cloudCoverPercent,
            uvIndex: uvIndex,
            temperatureC: temperatureC
        )
    }

    // MARK: - Mathematical Helpers

    private static func julianDate(from date: Date) -> Double {
        return 2440587.5 + (date.timeIntervalSince1970 / 86400.0)
    }

    private static func radians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }

    private static func degrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }

    private static func atmosphericRefraction(elevationDeg: Double) -> Double {
        guard elevationDeg > -0.85 else { return 0.0 }
        if elevationDeg > 5.0 {
            let elRad = radians(elevationDeg)
            let tanEl = tan(elRad)
            let rArcsec = (58.1 / tanEl) - (0.07 / pow(tanEl, 3)) + (0.000086 / pow(tanEl, 5))
            return rArcsec / 3600.0
        } else if elevationDeg > -0.575 {
            let val = -518.2 + elevationDeg * (103.4 + elevationDeg * (-12.79 + elevationDeg * 0.711))
            return (val + 1735.0) / 3600.0
        } else {
            return -20.774 / (tan(radians(elevationDeg)) * 3600.0)
        }
    }

    /// Converts a degree angle (0°–360°) to an 8-point Italian cardinal compass string (Nord, Nord-Est, etc.)
    public static func compassPoint(for degrees: Double) -> String {
        let normalized = (degrees.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let index = Int(round(normalized / 45.0)) % 8
        let points = [
            String(localized: "Nord"),
            String(localized: "Nord-Est"),
            String(localized: "Est"),
            String(localized: "Sud-Est"),
            String(localized: "Sud"),
            String(localized: "Sud-Ovest"),
            String(localized: "Ovest"),
            String(localized: "Nord-Ovest")
        ]
        return points[index]
    }

    /// Converts a degree angle (0°–360°) to a short 2-letter compass code (N, NE, E, SE, S, SW, W, NW).
    public static func shortCompass(for degrees: Double) -> String {
        let normalized = (degrees.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let index = Int(round(normalized / 45.0)) % 8
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return points[index]
    }
}
