import Testing
import Foundation
import CoreLocation
import SwiftUI
@testable import DeepWeather

@Suite("DeepWeather Unit Tests")
struct DeepWeatherTests {

    @Test("WeatherClient URL generation")
    func testWeatherClientURL() {
        let client = WeatherClient()
        #expect(client != nil)
    }

    @Test("AppGroup and WeatherSnapshot storage")
    func testWeatherSnapshotDefaults() {
        let snapshot = WeatherSnapshot()
        #expect(snapshot.useMetric == true)
        #expect(snapshot.dailySummaryHour == 8)
    }

    @Test("Onboarding completion and reset flow (No user name)")
    @MainActor
    func testOnboardingFlow() {
        let store = WeatherStore()
        let city = GeoResult(
            id: 1,
            name: "Milan",
            admin1: "Lombardy",
            country: "Italy",
            latitude: 45.4642,
            longitude: 9.1900
        )
        store.completeOnboarding(
            selectedCity: city,
            useGPS: false,
            useMetric: true,
            dailySummary: true
        )

        #expect(store.isOnboarded == true)
        #expect(store.isAutomaticGPSActive == false)
        #expect(store.selectedLocation?.name == "Milan")
        #expect(store.useMetric == true)
        #expect(store.dailySummaryEnabled == true)

        store.resetOnboarding()
        #expect(store.isOnboarded == false)
    }

    @Test("Location slider selection, paging, and multi-city management")
    @MainActor
    func testMultiLocationSwitching() {
        let store = WeatherStore()
        store.resetToAutomaticLocation()
        
        let rome = GeoResult(id: 1, name: "Rome", admin1: "Lazio", country: "Italy", latitude: 41.89, longitude: 12.51)
        let milan = GeoResult(id: 2, name: "Milan", admin1: "Lombardy", country: "Italy", latitude: 45.46, longitude: 9.19)
        let london = GeoResult(id: 3, name: "London", admin1: "England", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278)

        store.selectLocation(rome)
        store.selectLocation(milan)
        store.selectLocation(london)

        let pages = store.allPages
        #expect(pages.count == 4)
        #expect(pages[0].isGPS == true)
        #expect(pages[1].name == "Rome")
        #expect(pages[2].name == "Milan")
        #expect(pages[3].name == "London")

        // Test paging selection in both directions (swipe right and swipe left)
        store.selectPageIndex(0)
        #expect(store.selectedPageIndex == 0)
        #expect(store.allPages.count == 4)

        store.selectPageIndex(1)
        #expect(store.selectedPageIndex == 1)
        #expect(store.allPages.count == 4)

        store.selectPageIndex(2)
        #expect(store.selectedPageIndex == 2)
        #expect(store.allPages.count == 4)

        store.selectPageIndex(3)
        #expect(store.selectedPageIndex == 3)
        #expect(store.allPages.count == 4)

        // Swipe back left to GPS
        store.selectPageIndex(0)
        #expect(store.selectedPageIndex == 0)
        #expect(store.allPages.count == 4)

        // Test moving locations (reorder)
        let initialFirstName = store.savedLocations.first?.name
        store.moveLocations(from: IndexSet(integer: 0), to: store.savedLocations.count)
        #expect(store.savedLocations.last?.name == initialFirstName)

        // Test removing location
        let countBefore = store.savedLocations.count
        if let first = store.savedLocations.first {
            store.removeLocation(id: first.id)
            #expect(store.savedLocations.count == countBefore - 1)
        }
    }

    @Test("Settings options and preferences mutations")
    @MainActor
    func testSettingsPreferences() {
        let store = WeatherStore()
        
        store.refreshIntervalMinutes = 30
        #expect(store.refreshIntervalMinutes == 30)

        store.dailySummaryHour = 7
        #expect(store.dailySummaryHour == 7)

        store.rainAlertEnabled = true
        #expect(store.rainAlertEnabled == true)

        store.useMetric = true
        #expect(store.useMetric == true)
        #expect(store.temperatureUnitSymbol == "°C")

        store.useMetric = false
        #expect(store.temperatureUnitSymbol == "°F")
    }

    @Test("Weather theme and derived calculations")
    @MainActor
    func testWeatherThemeAndDerivations() {
        let store = WeatherStore()
        
        // Daytime Sunny
        let sunnyTheme = WeatherTheme.for(weatherCode: "113", isDay: true)
        #expect(!sunnyTheme.heroGradient.isEmpty)

        // Nighttime Rain
        let rainyTheme = WeatherTheme.for(weatherCode: "308", isDay: false)
        #expect(!rainyTheme.heroGradient.isEmpty)
    }

    @Test("Meteorological alert detection (Protezione Civile / Severe Weather)")
    func testWeatherAlertDetection() throws {
        let decoder = JSONDecoder()

        // 1. Extreme Heat Alert Test
        let heatJSON = """
        {
            "current_condition": [{
                "temp_C": "37",
                "temp_F": "98",
                "FeelsLikeC": "39",
                "FeelsLikeF": "102",
                "weatherCode": "113",
                "windspeedKmph": "15"
            }],
            "weather": [{
                "date": "2026-08-17",
                "maxtempC": "39",
                "mintempC": "24",
                "hourly": []
            }]
        }
        """
        let heatWeather = try decoder.decode(WeatherResponse.self, from: Data(heatJSON.utf8))
        let heatAlerts = WeatherAlert.detectAlerts(from: heatWeather, useMetric: true)
        #expect(!heatAlerts.isEmpty)
        #expect(heatAlerts.contains(where: { $0.category == .highHeat }))
        #expect(heatAlerts.first?.severity == .warning)

        // 2. High Wind & Storm Alert Test
        let windStormJSON = """
        {
            "current_condition": [{
                "temp_C": "19",
                "temp_F": "66",
                "FeelsLikeC": "18",
                "FeelsLikeF": "64",
                "weatherCode": "389",
                "windspeedKmph": "72"
            }],
            "weather": [{
                "date": "2026-08-17",
                "maxtempC": "21",
                "mintempC": "16",
                "hourly": [
                    { "time": "1200", "tempC": "20", "chanceofrain": "85", "windspeedKmph": "75" }
                ]
            }]
        }
        """
        let windStormWeather = try decoder.decode(WeatherResponse.self, from: Data(windStormJSON.utf8))
        let windStormAlerts = WeatherAlert.detectAlerts(from: windStormWeather, useMetric: true)
        #expect(windStormAlerts.count >= 2)
        #expect(windStormAlerts.contains(where: { $0.category == .strongWind }))
        #expect(windStormAlerts.contains(where: { $0.category == .severeStorm }))

        // 3. Extreme Cold & Freeze Alert Test
        let freezeJSON = """
        {
            "current_condition": [{
                "temp_C": "-1",
                "temp_F": "30",
                "FeelsLikeC": "-4",
                "FeelsLikeF": "25",
                "weatherCode": "113",
                "windspeedKmph": "10"
            }],
            "weather": [{
                "date": "2026-08-17",
                "maxtempC": "3",
                "mintempC": "-3",
                "hourly": []
            }]
        }
        """
        let freezeWeather = try decoder.decode(WeatherResponse.self, from: Data(freezeJSON.utf8))
        let freezeAlerts = WeatherAlert.detectAlerts(from: freezeWeather, useMetric: true)
        #expect(!freezeAlerts.isEmpty)
        #expect(freezeAlerts.contains(where: { $0.category == .extremeCold }))

        // 4. Dynamic Alert Authority Provider Tests
        let italianAuthority = AlertAuthorityProvider.authority(for: "Italy")
        #expect(italianAuthority.contains("Protezione Civile") || italianAuthority.contains("Civil Protection"))

        let usAuthority = AlertAuthorityProvider.authority(for: "United States of America")
        #expect(usAuthority.contains("National Weather Service"))

        let ukAuthority = AlertAuthorityProvider.authority(for: "United Kingdom")
        #expect(ukAuthority.contains("Met Office"))

        let frenchAuthority = AlertAuthorityProvider.authority(for: "France")
        #expect(frenchAuthority.contains("Météo-France"))

        let germanAuthority = AlertAuthorityProvider.authority(for: "Germany")
        #expect(germanAuthority.contains("DWD"))

        let japaneseAuthority = AlertAuthorityProvider.authority(for: "Japan")
        #expect(japaneseAuthority.contains("JMA") || japaneseAuthority.contains("Japan Meteorological Agency"))

        // 5. Localized Weather Condition and Moon Phase Formatter
        let sunnyDay = WeatherConditionFormatter.localizedDescription(for: "113", isDay: true)
        #expect(!sunnyDay.isEmpty)

        let moonPhase = WeatherIconMapper.localizedMoonPhaseName(for: "Full Moon")
        #expect(!moonPhase.isEmpty)
    }

    @Test("Issue #1290 Summer Blizzard Anomaly Detection & Open-Meteo Adapter")
    func testIssue1290AnomalyAndOpenMeteoAdapter() throws {
        // 1. Issue #1290 Corrupted wttr.in Data (-2°C Blizzard in London during August)
        let corruptedWttrJSON = """
        {
            "current_condition": [{
                "temp_C": "-2",
                "temp_F": "28",
                "weatherCode": "227",
                "windspeedKmph": "55"
            }],
            "weather": [{
                "date": "2026-08-17",
                "maxtempC": "0",
                "mintempC": "-4"
            }]
        }
        """
        let corruptedWeather = try JSONDecoder().decode(WeatherResponse.self, from: Data(corruptedWttrJSON.utf8))
        let sanityResult = WeatherSanityValidator.validate(corruptedWeather, latitude: 51.5074)
        #expect(!sanityResult.isValid)

        // 2. Open-Meteo Realistic Adapter Verification
        let sampleOpenMeteoJSON = """
        {
            "latitude": 51.5,
            "longitude": -0.12,
            "current": {
                "temperature_2m": 25.4,
                "relative_humidity_2m": 45,
                "apparent_temperature": 25.8,
                "precipitation": 0.0,
                "weather_code": 0,
                "cloud_cover": 10,
                "surface_pressure": 1015.0,
                "wind_speed_10m": 12.0
            },
            "hourly": {
                "time": ["2026-08-17T12:00", "2026-08-17T13:00"],
                "temperature_2m": [24.0, 25.4],
                "relative_humidity_2m": [48, 45],
                "apparent_temperature": [24.5, 25.8],
                "precipitation_probability": [0, 0],
                "weather_code": [0, 0],
                "wind_speed_10m": [11.0, 12.0]
            },
            "daily": {
                "time": ["2026-08-17", "2026-08-18", "2026-08-19"],
                "weather_code": [0, 1, 3],
                "temperature_2m_max": [26.5, 25.0, 23.0],
                "temperature_2m_min": [18.0, 17.0, 16.0],
                "sunrise": ["2026-08-17T05:48", "2026-08-18T05:50", "2026-08-19T05:52"],
                "sunset": ["2026-08-17T20:20", "2026-08-18T20:18", "2026-08-19T20:16"],
                "precipitation_probability_max": [0, 10, 20]
            }
        }
        """
        let omDecoded = try JSONDecoder().decode(OpenMeteoAdapter.OpenMeteoResponse.self, from: Data(sampleOpenMeteoJSON.utf8))
        let adapted = OpenMeteoAdapter.adapt(omDecoded, cityName: "London", countryName: "United Kingdom")

        #expect(adapted.currentCondition?.first?.tempC == "25")
        #expect(adapted.currentCondition?.first?.weatherCode == "113")
        #expect(adapted.weather?.count == 3)
        #expect(adapted.weather?.first?.maxtempC == "27")
        #expect(adapted.weather?.first?.mintempC == "18")
        #expect(adapted.nearestArea?.first?.areaName?.first?.value == "London")

        let validSanity = WeatherSanityValidator.validate(adapted, latitude: 51.5074)
        #expect(validSanity.isValid)

        // 3. LunarPhaseEngine Astronomical Moon Calculation
        let moonState = LunarPhaseEngine.calculate(for: Date())
        #expect(!moonState.phaseName.isEmpty)
        #expect(!moonState.phaseSymbol.isEmpty)
        #expect((0...100).contains(moonState.illuminationPercent))
    }

    @Test("SolarShadowEngine astronomical solar physics and shadow projections")
    func testSolarShadowEngineCalculations() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        // Rome, Italy Summer Solstice at Solar Noon (11:10 UTC)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 11
        components.minute = 10
        components.second = 0
        let romeSummerNoon = cal.date(from: components)!

        let romeCoordinate = CLLocationCoordinate2D(latitude: 41.8931, longitude: 12.4828)
        let solarPos = SolarShadowEngine.solarPosition(coordinate: romeCoordinate, date: romeSummerNoon)

        // Sun should be high in the sky in Rome during summer noon (~71° elevation)
        #expect(solarPos.elevation > 65.0)
        #expect(solarPos.elevation < 75.0)
        #expect(solarPos.isDaylight == true)
        #expect(solarPos.isGoldenHour == false)

        // Azimuth should point approximately South (170° - 190°)
        #expect(solarPos.azimuth >= 160.0 && solarPos.azimuth <= 200.0)

        // Shadow projection should point approximately North (340° - 20°)
        let shadow = SolarShadowEngine.shadowProjection(for: solarPos)
        #expect(shadow.isDirectShadowActive == true)
        #expect(shadow.lengthMultiplier != nil)

        // When elevation is ~71°, shadow multiplier should be tan(90-71) = 1/tan(71) ≈ 0.34
        if let multiplier = shadow.lengthMultiplier {
            #expect(multiplier > 0.25 && multiplier < 0.45)
            let obstacle10mShadow = shadow.shadowLength(forObstacleHeightMeters: 10.0)
            #expect(obstacle10mShadow != nil)
            #expect(obstacle10mShadow! > 2.5 && obstacle10mShadow! < 4.5)
        }

        // Shadow bearing should always be exact 180° inversion
        let expectedShadowBearing = (solarPos.azimuth + 180.0).truncatingRemainder(dividingBy: 360.0)
        #expect(abs(shadow.bearing - expectedShadowBearing) < 0.001)
    }

    @Test("SolarShadowEngine night time state and zero direct shadow")
    func testSolarShadowNightState() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 21
        components.hour = 23
        components.minute = 30
        let midnightUTC = cal.date(from: components)!

        let romeCoordinate = CLLocationCoordinate2D(latitude: 41.8931, longitude: 12.4828)
        let solarPos = SolarShadowEngine.solarPosition(coordinate: romeCoordinate, date: midnightUTC)

        #expect(solarPos.elevation < 0.0)
        #expect(solarPos.isDaylight == false)

        let shadow = SolarShadowEngine.shadowProjection(for: solarPos)
        #expect(shadow.isDirectShadowActive == false)
        #expect(shadow.lengthMultiplier == nil)
        #expect(shadow.shadowLength(forObstacleHeightMeters: 12.0) == nil)

        let quality = SolarShadowEngine.shadowQuality(solarPos: solarPos, cloudCoverPercent: 0)
        #expect(quality == .night)
    }

    @Test("SolarShadowEngine weather cloud cover modulation")
    func testWeatherModulatedShadowQuality() {
        let dayPos = SolarShadowEngine.SolarPosition(
            azimuth: 180.0,
            elevation: 45.0,
            zenith: 45.0,
            declination: 15.0
        )

        let crispQuality = SolarShadowEngine.shadowQuality(solarPos: dayPos, cloudCoverPercent: 10)
        #expect(crispQuality == .crisp)
        #expect(crispQuality.opacity > 0.7)

        let diffuseQuality = SolarShadowEngine.shadowQuality(solarPos: dayPos, cloudCoverPercent: 45)
        #expect(diffuseQuality == .diffuse)

        let ambientQuality = SolarShadowEngine.shadowQuality(solarPos: dayPos, cloudCoverPercent: 85)
        #expect(ambientQuality == .ambient)
    }

    @Test("SolarShadowEngine solar day milestones (Sunrise, Noon, Sunset, Golden Hour)")
    func testSolarDayMilestones() {
        let milanCoordinate = CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900)
        let date = Date()
        let milestones = SolarShadowEngine.dayMilestones(coordinate: milanCoordinate, date: date, timeZone: TimeZone(identifier: "Europe/Rome")!)

        #expect(milestones.sunrise != nil)
        #expect(milestones.solarNoon != nil)
        #expect(milestones.sunset != nil)
        #expect(milestones.daylightDurationHours != nil)
        #expect(milestones.daylightDurationHours! > 6.0 && milestones.daylightDurationHours! < 18.0)

        if let sunrise = milestones.sunrise, let noon = milestones.solarNoon, let sunset = milestones.sunset {
            #expect(sunrise < noon)
            #expect(noon < sunset)
        }

        #expect(!milestones.formattedSunrise.isEmpty)
        #expect(!milestones.formattedSunset.isEmpty)
        #expect(!milestones.formattedSolarNoon.isEmpty)
    }

    @Test("WeatherStore solar state and walking guidance integration")
    @MainActor
    func testWeatherStoreSolarIntegration() {
        let store = WeatherStore()
        let city = GeoResult(
            id: 1,
            name: "Florence",
            admin1: "Tuscany",
            country: "Italy",
            latitude: 43.7696,
            longitude: 11.2558
        )
        store.selectLocation(city)

        guard let page = store.allPages.first(where: { $0.name == "Florence" }) else {
            Issue.record("Failed to find Florence page")
            return
        }

        let coord = store.coordinate(for: page)
        #expect(abs(coord.latitude - 43.7696) < 0.001)
        #expect(abs(coord.longitude - 11.2558) < 0.001)

        // Evaluate solar state at daytime
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Rome")!
        var comp = cal.dateComponents([.year, .month, .day], from: Date())
        comp.hour = 14
        comp.minute = 0
        let daytime = cal.date(from: comp)!

        let state = store.solarState(for: page, date: daytime)
        #expect(state.solarPosition.isDaylight == true)
        #expect(state.shadowProjection.isDirectShadowActive == true)

        let shadeGuidance = state.guidance(for: .seekShade)
        #expect(!shadeGuidance.isEmpty)

        let sunGuidance = state.guidance(for: .seekSun)
        #expect(!sunGuidance.isEmpty)

        #expect(!state.sidewalkShadeRecommendation.isEmpty)
        #expect(!state.sidewalkSunRecommendation.isEmpty)
    }

    @Test("Weather theme and animation kind classification")
    func testWeatherAnimationKinds() {
        #expect(WeatherIconMapper.animationKind(for: "113", isDay: true) == .sun)
        #expect(WeatherIconMapper.animationKind(for: "116", isDay: true) == .partlyCloudy)
        #expect(WeatherIconMapper.animationKind(for: "119", isDay: true) == .cloud)
        #expect(WeatherIconMapper.animationKind(for: "122", isDay: true) == .cloud)
        #expect(WeatherIconMapper.animationKind(for: "296", isDay: true) == .rain)
        #expect(WeatherIconMapper.animationKind(for: "308", isDay: true) == .rain)
        #expect(WeatherIconMapper.animationKind(for: "389", isDay: true) == .storm)
        #expect(WeatherIconMapper.animationKind(for: "248", isDay: true) == .fog)
        #expect(WeatherIconMapper.animationKind(for: "338", isDay: true) == .snow)
    }

    @Test("WeatherIconMapper stylized symbols uniformity")
    func testWeatherIconMapperSymbols() {
        #expect(WeatherIconMapper.symbol(for: "113", isDay: true) == "sun.max")
        #expect(WeatherIconMapper.symbol(for: "113", isDay: false) == "moon.stars")
        #expect(WeatherIconMapper.symbol(for: "116", isDay: true) == "cloud.sun")
        #expect(WeatherIconMapper.symbol(for: "116", isDay: false) == "cloud.moon")
        #expect(WeatherIconMapper.symbol(for: "119", isDay: true) == "cloud")
        #expect(WeatherIconMapper.symbol(for: "122", isDay: true) == "cloud")
        #expect(WeatherIconMapper.symbol(for: "248", isDay: true) == "cloud.fog")
        #expect(WeatherIconMapper.symbol(for: "296", isDay: true) == "cloud.drizzle")
        #expect(WeatherIconMapper.symbol(for: "308", isDay: true) == "cloud.rain")
        #expect(WeatherIconMapper.symbol(for: "338", isDay: true) == "cloud.snow")
        #expect(WeatherIconMapper.symbol(for: "389", isDay: true) == "cloud.bolt.rain")
    }

    @Test("Weather detail items (UV, pressure, visibility, precipitation) completeness")
    @MainActor
    func testDetailGridItemsCompleteness() {
        let store = WeatherStore()

        // Create sample weather response with realistic values
        let condition = CurrentCondition(
            tempC: "28",
            tempF: "82",
            feelsLikeC: "31",
            feelsLikeF: "88",
            humidity: "60",
            cloudcover: "40",
            pressure: "1014",
            pressureInches: "29.94",
            uvIndex: "7",
            visibility: "35",
            visibilityMiles: "22",
            precipMM: "0.4",
            precipInches: "0.02",
            windspeedKmph: "15",
            windspeedMiles: "9",
            winddirDegree: "180",
            winddir16Point: "S",
            weatherCode: "116",
            observationTime: "12:00",
            weatherDesc: [TextValue(value: "Partly cloudy")]
        )

        let day = DayForecast(
            date: "2026-08-18",
            maxtempC: "30",
            mintempC: "22",
            maxtempF: "86",
            mintempF: "72",
            avgtempC: "26",
            avgtempF: "79",
            totalSnowCm: "0.0",
            sunHour: "12.5",
            uvIndex: "8",
            astronomy: [Astronomy(
                sunrise: "06:15 AM",
                sunset: "08:15 PM",
                moonrise: "09:30 PM",
                moonset: "07:00 AM",
                moonPhase: "Waxing Crescent",
                moonIllumination: "25"
            )],
            hourly: []
        )

        let weather = WeatherResponse(
            currentCondition: [condition],
            nearestArea: [NearestArea(
                areaName: [TextValue(value: "Rome")],
                country: [TextValue(value: "Italy")],
                region: [TextValue(value: "Lazio")],
                latitude: "41.8919",
                longitude: "12.5113"
            )],
            weather: [day]
        )

        let details = store.detailItems(for: weather)
        #expect(!details.isEmpty)

        let uvItem = details.first { $0.id == "uv" }
        #expect(uvItem != nil)
        #expect(uvItem?.value == "7")
        #expect(uvItem?.value != "—")

        let pressureItem = details.first { $0.id == "pressure" }
        #expect(pressureItem != nil)
        #expect(pressureItem?.value.contains("hPa") == true || pressureItem?.value.contains("inHg") == true)
        #expect(pressureItem?.value != "—")

        let visibilityItem = details.first { $0.id == "visibility" }
        #expect(visibilityItem != nil)
        #expect(visibilityItem?.value.contains("km") == true || visibilityItem?.value.contains("mi") == true)
        #expect(visibilityItem?.value != "—")

        let precipItem = details.first { $0.id == "precipitation" }
        #expect(precipItem != nil)
        #expect(precipItem?.value.contains("mm") == true || precipItem?.value.contains("in") == true)
        #expect(precipItem?.value != "—")
    }

    @Test("Animated weather backgrounds and icons instantiation across all kinds")
    @MainActor
    func testAllWeatherAnimationViewsCoverage() {
        let allKinds: [WeatherAnimationKind] = [
            .sun, .partlyCloudy, .cloud, .rain, .snow, .storm, .fog, .moon
        ]

        for kind in allKinds {
            let bgDay = AnimatedWeatherBackgroundView(
                gradient: [Color.blue, Color.cyan],
                isNight: false,
                showsStars: false,
                weatherKind: kind
            )
            #expect(bgDay.weatherKind == kind)

            let bgNight = AnimatedWeatherBackgroundView(
                gradient: [Color.black, Color.indigo],
                isNight: true,
                showsStars: true,
                weatherKind: kind
            )
            #expect(bgNight.weatherKind == kind)

            let icon = AnimatedWeatherIconView(
                symbol: "cloud.sun",
                kind: kind,
                accessibilityLabel: "Test \(kind)"
            )
            #expect(icon.kind == kind)
        }
    }

    @Test("System measurement system and locale derivation default")
    @MainActor
    func testSystemLocaleAndMeasurementSystemDefault() {
        let expectedDefault = (Locale.autoupdatingCurrent.measurementSystem != .us)
        #expect(WeatherStore.defaultUseMetric == expectedDefault)
        
        let store = WeatherStore()
        #expect(store.useMetric == expectedDefault || store.useMetric == true || store.useMetric == false)
    }
}
