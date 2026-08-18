import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class WeatherStore {

    // MARK: - View models

    struct DetailItem: Identifiable, Sendable {
        let id: String
        let symbol: String
        let title: String
        let value: String
    }

    struct HourlyItem: Identifiable, Sendable {
        let id: String
        let hourText: String
        let symbol: String
        let tempText: String
        let precipChance: Int
    }

    struct DayItem: Identifiable, Sendable {
        let id: String
        let title: String
        let symbol: String
        let minText: String
        let maxText: String
        let minValue: Double
        let maxValue: Double
        let minTempC: Double
        let maxTempC: Double
        let precipChance: Int
        let isToday: Bool
    }

    struct ChartPoint: Identifiable, Sendable {
        let id: Date
        let date: Date
        let temperature: Double?
        let precipChance: Int
    }

    struct MoonItem: Identifiable, Sendable {
        let id: String
        let title: String
        let phaseSymbol: String
        let phaseName: String
        let illuminationText: String
    }

    struct WeatherPageItem: Identifiable, Equatable, Hashable {
        let id: String // "gps" or savedLocation.id
        let isGPS: Bool
        let name: String
        let detail: String
        let latitude: Double?
        let longitude: Double?
    }

    // MARK: - State

    private(set) var weather: WeatherResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    // Multi-location weather cache & per-location state
    private(set) var locationWeatherCache: [String: WeatherResponse] = [:]
    private(set) var locationLoadingStates: [String: Bool] = [:]
    private(set) var locationErrorMessages: [String: String] = [:]

    // Precomputed derived view models for active location (60fps performance)
    private(set) var detailItems: [DetailItem] = []
    private(set) var chartMidnights: [Date] = []
    private(set) var chartPoints: [ChartPoint] = []
    private(set) var moonItems: [MoonItem] = []
    private(set) var upcomingHours: [HourlyItem] = []
    private(set) var dayItems: [DayItem] = []

    private(set) var savedLocations: [SavedLocation] = [] {
        didSet { persistSettings() }
    }

    var selectedLocationID: String? = nil {
        didSet {
            persistSettings()
            syncActiveWeatherFromCache()
        }
    }

    var useMetric: Bool = true {
        didSet {
            persistSettings()
            recomputeDerivedState()
        }
    }

    var refreshIntervalMinutes: Int = 15 {
        didSet {
            persistSettings()
            if autoRefreshTask != nil { scheduleAutoRefresh() }
        }
    }

    var dailySummaryEnabled: Bool = false {
        didSet { persistSettings() }
    }

    var dailySummaryHour: Int = 8 {
        didSet { persistSettings() }
    }

    var rainAlertEnabled: Bool = false {
        didSet { persistSettings() }
    }

    /// Whether the initial setup has been completed.
    private(set) var isOnboarded: Bool = false {
        didSet { persistSettings() }
    }

    /// Active weather data provider source (Auto, Open-Meteo, wttr.in).
    var weatherProvider: WeatherProvider = .auto {
        didSet {
            persistSettings()
            Task { await refresh() }
        }
    }

    /// Whether automatic GPS location mode was chosen by the user.
    private(set) var isAutomaticGPSActive: Bool = false {
        didSet {
            persistSettings()
            syncActiveWeatherFromCache()
        }
    }

    /// Dynamic color theme derived from the active weather.
    var theme: WeatherTheme {
        theme(for: weather)
    }

    /// Coordinates reported by CoreLocation when in automatic (GPS) mode.
    private(set) var automaticLatitude: Double?
    private(set) var automaticLongitude: Double?

    var selectedLocation: SavedLocation? {
        savedLocations.first { $0.id == selectedLocationID }
    }

    private let client: WeatherClient
    private let defaults: UserDefaults
    private var autoRefreshTask: Task<Void, Never>?
    private let dateParser: DateFormatter
    private let weekdayFormatter: DateFormatter

    // MARK: - Pages & Navigation

    var allPages: [WeatherPageItem] {
        var pages: [WeatherPageItem] = []
        let gpsWeather = weather(for: "gps")
        let gpsName = gpsWeather?.nearestArea?.first?.areaName?.first?.value ?? String(localized: "Current location")
        let gpsDetail = gpsWeather?.nearestArea?.first.flatMap { area in
            [area.region?.first?.value, area.country?.first?.value].compactMap { $0 }.joined(separator: ", ")
        } ?? ""
        pages.append(WeatherPageItem(
            id: "gps",
            isGPS: true,
            name: gpsName,
            detail: gpsDetail,
            latitude: automaticLatitude,
            longitude: automaticLongitude
        ))

        for loc in savedLocations {
            pages.append(WeatherPageItem(
                id: loc.id,
                isGPS: false,
                name: loc.name,
                detail: loc.detail,
                latitude: loc.latitude,
                longitude: loc.longitude
            ))
        }
        return pages
    }

    var selectedPageIndex: Int {
        let pages = allPages
        guard !pages.isEmpty else { return 0 }
        if isAutomaticGPSActive || selectedLocationID == nil {
            return 0
        }
        if let selectedLocationID,
           let idx = pages.firstIndex(where: { $0.id == selectedLocationID }) {
            return idx
        }
        return 0
    }

    func selectPageIndex(_ index: Int) {
        let pages = allPages
        guard index >= 0 && index < pages.count else { return }
        let target = pages[index]
        if target.isGPS {
            resetToAutomaticLocation()
        } else {
            selectSavedLocation(target.id)
        }
    }

    func weather(for id: String) -> WeatherResponse? {
        if let cached = locationWeatherCache[id] {
            return cached
        }
        if id == "gps" && isAutomaticGPSActive && selectedLocationID == nil {
            return weather
        }
        if id == selectedLocationID {
            return weather
        }
        return nil
    }

    func isPageLoading(for id: String) -> Bool {
        locationLoadingStates[id] ?? (isLoading && (id == selectedLocationID || (id == "gps" && isAutomaticGPSActive)))
    }

    func errorMessage(for id: String) -> String? {
        locationErrorMessages[id] ?? ((id == selectedLocationID || (id == "gps" && isAutomaticGPSActive)) ? errorMessage : nil)
    }

    // MARK: - Init

    init(client: WeatherClient = WeatherClient()) {
        self.client = client
        self.defaults = AppGroup.defaults

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        self.dateParser = parser

        let weekday = DateFormatter()
        weekday.locale = Locale.autoupdatingCurrent
        weekday.dateFormat = "EEE"
        self.weekdayFormatter = weekday

        self.useMetric = defaults.object(forKey: Self.useMetricKey) as? Bool ?? (UserDefaults.standard.object(forKey: Self.useMetricKey) as? Bool ?? true)
        self.refreshIntervalMinutes = defaults.object(forKey: Self.refreshIntervalKey) as? Int ?? (UserDefaults.standard.object(forKey: Self.refreshIntervalKey) as? Int ?? 15)
        self.dailySummaryEnabled = defaults.object(forKey: Self.dailySummaryEnabledKey) as? Bool ?? (UserDefaults.standard.object(forKey: Self.dailySummaryEnabledKey) as? Bool ?? false)
        self.dailySummaryHour = defaults.object(forKey: Self.dailySummaryHourKey) as? Int ?? (UserDefaults.standard.object(forKey: Self.dailySummaryHourKey) as? Int ?? 8)
        self.rainAlertEnabled = defaults.object(forKey: Self.rainAlertEnabledKey) as? Bool ?? (UserDefaults.standard.object(forKey: Self.rainAlertEnabledKey) as? Bool ?? false)
        self.isOnboarded = defaults.bool(forKey: Self.isOnboardedKey) || UserDefaults.standard.bool(forKey: Self.isOnboardedKey)
        self.isAutomaticGPSActive = defaults.bool(forKey: Self.isAutomaticGPSActiveKey) || UserDefaults.standard.bool(forKey: Self.isAutomaticGPSActiveKey)

        if let provStr = defaults.string(forKey: Self.weatherProviderKey) ?? UserDefaults.standard.string(forKey: Self.weatherProviderKey),
           let prov = WeatherProvider(rawValue: provStr) {
            self.weatherProvider = prov
        } else {
            self.weatherProvider = .auto
        }

        var locData = defaults.data(forKey: Self.savedLocationsKey) ?? UserDefaults.standard.data(forKey: Self.savedLocationsKey)
        if locData == nil {
            if let str = defaults.string(forKey: Self.savedLocationsKey) ?? UserDefaults.standard.string(forKey: Self.savedLocationsKey) {
                locData = str.data(using: .utf8)
            }
        }
        if let locData,
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: locData) {
            self.savedLocations = decoded
        } else if let data = defaults.data(forKey: Self.legacySavedLocationKey) ?? UserDefaults.standard.data(forKey: Self.legacySavedLocationKey),
                  let legacy = SavedLocationMigration.legacy(from: data) {
            self.savedLocations = [legacy]
            defaults.removeObject(forKey: Self.legacySavedLocationKey)
            UserDefaults.standard.removeObject(forKey: Self.legacySavedLocationKey)
        }

        let selectedID = defaults.string(forKey: Self.selectedLocationKey) ?? UserDefaults.standard.string(forKey: Self.selectedLocationKey)
        if let selectedID, savedLocations.contains(where: { $0.id == selectedID }) {
            self.selectedLocationID = selectedID
        } else {
            self.selectedLocationID = savedLocations.first?.id
            defaults.removeObject(forKey: Self.selectedLocationKey)
        }

        // Restore weather from snapshot if available for instant launch
        let snapshot = WeatherSnapshot.load(from: defaults)
        if let cachedWeather = snapshot.weather {
            self.weather = cachedWeather
            self.lastUpdated = snapshot.lastUpdated
            let initialKey = selectedLocationID ?? (isAutomaticGPSActive ? "gps" : (savedLocations.first?.id ?? "gps"))
            self.locationWeatherCache[initialKey] = cachedWeather
            recomputeDerivedState()
        }
    }

    private static let useMetricKey = "weatherbar.useMetric"
    private static let savedLocationsKey = "weatherbar.savedLocations"
    private static let selectedLocationKey = "weatherbar.selectedLocationID"
    private static let legacySavedLocationKey = "weatherbar.savedLocation"
    private static let refreshIntervalKey = "weatherbar.refreshIntervalMinutes"
    private static let dailySummaryEnabledKey = "weatherbar.dailySummaryEnabled"
    private static let dailySummaryHourKey = "weatherbar.dailySummaryHour"
    private static let rainAlertEnabledKey = "weatherbar.rainAlertEnabled"
    private static let isOnboardedKey = "weatherbar.isOnboarded"
    private static let isAutomaticGPSActiveKey = "weatherbar.isAutomaticGPSActive"
    private static let weatherProviderKey = "weatherbar.weatherProvider"

    // MARK: - Onboarding

    @MainActor
    func completeOnboarding(
        selectedCity: GeoResult?,
        useGPS: Bool,
        useMetric: Bool,
        dailySummary: Bool
    ) {
        self.useMetric = useMetric
        self.dailySummaryEnabled = dailySummary

        if useGPS {
            self.isAutomaticGPSActive = true
            self.selectedLocationID = nil
        } else if let selectedCity {
            self.isAutomaticGPSActive = false
            let newLoc = SavedLocation(
                id: UUID().uuidString,
                name: selectedCity.name,
                detail: selectedCity.detail,
                latitude: selectedCity.latitude,
                longitude: selectedCity.longitude
            )
            self.savedLocations = [newLoc]
            self.selectedLocationID = newLoc.id
        }

        self.isOnboarded = true
        applySettings()
    }

    @MainActor
    func resetOnboarding() {
        self.isOnboarded = false
        persistSettings()
    }

    // MARK: - Lifecycle

    @MainActor
    func startAutoRefresh(immediately: Bool = true) {
        guard autoRefreshTask == nil else { return }
        scheduleAutoRefresh()
        if immediately {
            Task { await refresh() }
        }
    }

    private func scheduleAutoRefresh() {
        autoRefreshTask?.cancel()
        let interval = TimeInterval(refreshIntervalMinutes * 60)
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    @MainActor
    func applySettings() {
        scheduleAutoRefresh()
        Task { await refresh() }
    }

    // MARK: - Automatic location (CoreLocation)

    @MainActor
    func setAutomaticCoordinate(latitude: Double, longitude: Double) {
        automaticLatitude = latitude
        automaticLongitude = longitude
        persistSettings()
    }

    // MARK: - Locations

    @MainActor
    func selectLocation(_ result: GeoResult) {
        isAutomaticGPSActive = false
        if let existing = savedLocations.first(where: {
            abs($0.latitude - result.latitude) < 0.001 && abs($0.longitude - result.longitude) < 0.001
        }) {
            selectedLocationID = existing.id
        } else {
            let newLocation = SavedLocation(
                id: UUID().uuidString,
                name: result.name,
                detail: result.detail,
                latitude: result.latitude,
                longitude: result.longitude
            )
            savedLocations.append(newLocation)
            selectedLocationID = newLocation.id
        }
        applySettings()
    }

    @MainActor
    func selectSavedLocation(_ id: String?) {
        guard selectedLocationID != id else { return }
        if id != nil {
            isAutomaticGPSActive = false
        }
        selectedLocationID = id
        syncActiveWeatherFromCache()
        applySettings()
    }

    @MainActor
    func removeLocation(id: String) {
        savedLocations.removeAll { $0.id == id }
        locationWeatherCache.removeValue(forKey: id)
        locationLoadingStates.removeValue(forKey: id)
        locationErrorMessages.removeValue(forKey: id)
        if selectedLocationID == id {
            selectedLocationID = savedLocations.first?.id
        }
        syncActiveWeatherFromCache()
        applySettings()
    }

    @MainActor
    func moveLocations(from source: IndexSet, to destination: Int) {
        savedLocations.move(fromOffsets: source, toOffset: destination)
        persistSettings()
    }

    @MainActor
    func resetToAutomaticLocation() {
        isAutomaticGPSActive = true
        selectedLocationID = nil
        syncActiveWeatherFromCache()
        applySettings()
    }

    private func syncActiveWeatherFromCache() {
        let key = isAutomaticGPSActive && selectedLocationID == nil ? "gps" : (selectedLocationID ?? "gps")
        if let cached = locationWeatherCache[key] {
            self.weather = cached
            recomputeDerivedState()
        }
    }

    // MARK: - Fetching

    @MainActor
    func fetchWeather(for page: WeatherPageItem, force: Bool = false) async {
        let key = page.id
        if !force && locationWeatherCache[key] != nil && locationErrorMessages[key] == nil {
            return
        }
        locationLoadingStates[key] = true
        locationErrorMessages[key] = nil

        do {
            let query: String?
            let lat: Double?
            let lon: Double?
            if page.isGPS {
                lat = automaticLatitude
                lon = automaticLongitude
                if let automaticLatitude, let automaticLongitude {
                    query = String(format: "%.5f,%.5f", automaticLatitude, automaticLongitude)
                } else {
                    query = nil
                }
            } else {
                lat = page.latitude
                lon = page.longitude
                if let lat, let lon {
                    query = String(format: "%.5f,%.5f", lat, lon)
                } else {
                    query = nil
                }
            }

            let result = try await client.fetch(
                location: query,
                latitude: lat,
                longitude: lon,
                cityName: page.name,
                countryName: page.detail,
                provider: weatherProvider
            )
            locationWeatherCache[key] = result
            locationLoadingStates[key] = false

            let isCurrent = (page.isGPS && isAutomaticGPSActive && selectedLocationID == nil) || page.id == selectedLocationID
            if isCurrent || weather == nil {
                self.weather = result
                self.lastUpdated = Date()
                recomputeDerivedState()
                saveSnapshot()
            }
        } catch {
            locationLoadingStates[key] = false
            locationErrorMessages[key] = friendlyMessage(for: error)
            if (page.isGPS && isAutomaticGPSActive && selectedLocationID == nil) || page.id == selectedLocationID {
                self.errorMessage = friendlyMessage(for: error)
            }
        }
    }

    @MainActor
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let pages = allPages
        if pages.isEmpty {
            do {
                let query: String?
                if let automaticLatitude, let automaticLongitude {
                    query = String(format: "%.5f,%.5f", automaticLatitude, automaticLongitude)
                } else {
                    query = nil
                }
                let res = try await client.fetch(location: query)
                self.weather = res
                self.locationWeatherCache["gps"] = res
                self.lastUpdated = Date()
                recomputeDerivedState()
                saveSnapshot()
            } catch {
                self.errorMessage = friendlyMessage(for: error)
            }
            return
        }

        await withTaskGroup(of: Void.self) { group in
            for page in pages {
                group.addTask { [weak self] in
                    await self?.fetchWeather(for: page, force: true)
                }
            }
        }

        let currentKey = isAutomaticGPSActive && selectedLocationID == nil ? "gps" : (selectedLocationID ?? (pages.first?.id ?? "gps"))
        if let active = locationWeatherCache[currentKey] {
            self.weather = active
            self.lastUpdated = Date()
            recomputeDerivedState()
            saveSnapshot()
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let clientError = error as? WeatherClient.ClientError {
            return clientError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return String(localized: "No internet connection.")
            case .timedOut:
                return String(localized: "Request timed out.")
            default:
                break
            }
        }
        return String(localized: "Couldn't read the weather data.")
    }

    // MARK: - Persistence

    private func persistSettings() {
        defaults.set(useMetric, forKey: Self.useMetricKey)
        defaults.set(refreshIntervalMinutes, forKey: Self.refreshIntervalKey)
        defaults.set(dailySummaryEnabled, forKey: Self.dailySummaryEnabledKey)
        defaults.set(dailySummaryHour, forKey: Self.dailySummaryHourKey)
        defaults.set(rainAlertEnabled, forKey: Self.rainAlertEnabledKey)
        defaults.set(isOnboarded, forKey: Self.isOnboardedKey)
        defaults.set(isAutomaticGPSActive, forKey: Self.isAutomaticGPSActiveKey)
        defaults.set(weatherProvider.rawValue, forKey: Self.weatherProviderKey)
        if let data = try? JSONEncoder().encode(savedLocations) {
            defaults.set(data, forKey: Self.savedLocationsKey)
        } else {
            defaults.removeObject(forKey: Self.savedLocationsKey)
        }
        if let selectedLocationID {
            defaults.set(selectedLocationID, forKey: Self.selectedLocationKey)
        } else {
            defaults.removeObject(forKey: Self.selectedLocationKey)
        }
        saveSnapshot()
    }

    /// Writes the cached weather + settings snapshot shared with the widgets.
    private func saveSnapshot() {
        var snapshot = WeatherSnapshot.load(from: defaults)
        if let weather {
            snapshot.weather = weather
            snapshot.lastUpdated = lastUpdated
            snapshot.locationName = locationName
            snapshot.locationDetail = locationDetail
        }
        snapshot.useMetric = useMetric
        snapshot.latitude = selectedLocation?.latitude ?? automaticLatitude
        snapshot.longitude = selectedLocation?.longitude ?? automaticLongitude
        snapshot.dailySummaryEnabled = dailySummaryEnabled
        snapshot.dailySummaryHour = dailySummaryHour
        snapshot.rainAlertEnabled = rainAlertEnabled
        snapshot.save(to: defaults)
    }

    // MARK: - Current conditions & computation helpers

    var menuBarIcon: String {
        WeatherIconMapper.symbol(
            for: weather?.currentCondition?.first?.weatherCode,
            isDay: isDay
        )
    }

    var menuBarAnimationKind: WeatherAnimationKind {
        WeatherIconMapper.animationKind(
            for: weather?.currentCondition?.first?.weatherCode,
            isDay: isDay
        )
    }

    var menuBarTemp: String { currentTempText }

    var currentTempValue: Double? {
        currentTempValue(for: weather)
    }

    func currentTempValue(for weather: WeatherResponse?) -> Double? {
        let raw = useMetric
            ? weather?.currentCondition?.first?.tempC
            : weather?.currentCondition?.first?.tempF
        return raw.flatMap { Double($0) }
    }

    var currentTempText: String {
        currentTempText(for: weather)
    }

    func currentTempText(for weather: WeatherResponse?) -> String {
        guard let c = weather?.currentCondition?.first else { return "--°" }
        return tempString(c.tempC, c.tempF)
    }

    var temperatureUnitSymbol: String {
        useMetric ? "°C" : "°F"
    }

    var locationName: String {
        if let selected = selectedLocation {
            return selected.name
        }
        return weather?.nearestArea?.first?.areaName?.first?.value ?? String(localized: "Current location")
    }

    var locationDetail: String {
        if let selected = selectedLocation, !selected.detail.isEmpty {
            return selected.detail
        }
        guard let area = weather?.nearestArea?.first else { return "" }
        return [area.region?.first?.value, area.country?.first?.value]
            .compactMap { $0 }.joined(separator: ", ")
    }

    func locationName(for page: WeatherPageItem, weather: WeatherResponse?) -> String {
        if !page.isGPS {
            return page.name
        }
        return weather?.nearestArea?.first?.areaName?.first?.value ?? page.name
    }

    func locationDetail(for page: WeatherPageItem, weather: WeatherResponse?) -> String {
        if !page.isGPS && !page.detail.isEmpty {
            return page.detail
        }
        guard let area = weather?.nearestArea?.first else { return page.detail }
        return [area.region?.first?.value, area.country?.first?.value]
            .compactMap { $0 }.joined(separator: ", ")
    }

    var currentConditionText: String {
        currentConditionText(for: weather)
    }

    func currentConditionText(for weather: WeatherResponse?) -> String {
        let code = weather?.currentCondition?.first?.weatherCode
        let fallback = weather?.currentCondition?.first?.conditionDescription
        return WeatherConditionFormatter.localizedDescription(for: code, isDay: isDay(for: weather), fallback: fallback)
    }

    var isDay: Bool {
        isDay(for: weather)
    }

    func isDay(for weather: WeatherResponse?) -> Bool {
        guard let astro = weather?.weather?.first?.astronomy?.first,
              let sunrise = Self.minutes(from12h: astro.sunrise),
              let sunset = Self.minutes(from12h: astro.sunset)
        else {
            return (6..<21).contains(Calendar.current.component(.hour, from: Date()))
        }
        let calendar = Calendar.current
        let minutes = calendar.component(.hour, from: Date()) * 60 + calendar.component(.minute, from: Date())
        return minutes >= sunrise && minutes < sunset
    }

    func theme(for weather: WeatherResponse?) -> WeatherTheme {
        WeatherTheme.for(
            weatherCode: weather?.currentCondition?.first?.weatherCode,
            isDay: isDay(for: weather)
        )
    }

    // MARK: - Derived state precomputation

    private func recomputeDerivedState() {
        detailItems = detailItems(for: weather)
        chartMidnights = chartMidnights(for: weather)
        chartPoints = chartPoints(for: weather)
        moonItems = moonItems(for: weather)
        upcomingHours = upcomingHours(for: weather)
        dayItems = dayItems(for: weather)
    }

    func alerts(for weather: WeatherResponse?) -> [WeatherAlert] {
        WeatherAlert.detectAlerts(from: weather, useMetric: useMetric)
    }

    func detailItems(for weather: WeatherResponse?) -> [DetailItem] {
        guard let weather, let c = weather.currentCondition?.first else { return [] }
        let today = weather.weather?.first
        let astro = today?.astronomy?.first
        var items = [
            DetailItem(id: "feels", symbol: "thermometer.medium", title: String(localized: "Feels like"), value: tempString(c.feelsLikeC, c.feelsLikeF)),
            DetailItem(id: "humidity", symbol: "humidity", title: String(localized: "Humidity"), value: c.humidity.map { "\($0)%" } ?? "—"),
            DetailItem(id: "wind", symbol: "wind", title: String(localized: "Wind"), value: windString(c.windspeedKmph, c.windspeedMiles, dir: c.winddir16Point)),
            DetailItem(id: "uv", symbol: "sun.max", title: String(localized: "UV index"), value: uvString(c, today: today)),
            DetailItem(id: "pressure", symbol: "gauge", title: String(localized: "Pressure"), value: pressureString(c)),
            DetailItem(id: "visibility", symbol: "eye", title: String(localized: "Visibility"), value: visibilityString(c)),
            DetailItem(id: "precipitation", symbol: "drop", title: String(localized: "Precipitation"), value: precipString(c)),
            DetailItem(id: "cloudcover", symbol: "cloud", title: String(localized: "Cloud cover"), value: c.cloudcover.map { "\($0)%" } ?? "—")
        ]
        if let sunrise = astro?.sunrise {
            items.append(DetailItem(id: "sunrise", symbol: "sunrise", title: String(localized: "Sunrise"), value: sunrise))
        }
        if let sunset = astro?.sunset {
            items.append(DetailItem(id: "sunset", symbol: "sunset", title: String(localized: "Sunset"), value: sunset))
        }
        if let moonrise = astro?.moonrise {
            items.append(DetailItem(id: "moonrise", symbol: "moonrise", title: String(localized: "Moonrise"), value: moonrise))
        }
        if let moonset = astro?.moonset {
            items.append(DetailItem(id: "moonset", symbol: "moonset", title: String(localized: "Moonset"), value: moonset))
        }
        return items
    }

    func chartMidnights(for weather: WeatherResponse?) -> [Date] {
        guard let days = weather?.weather else { return [] }
        return days.compactMap { day in
            day.date.flatMap { dateParser.date(from: $0) }
        }
    }

    func chartPoints(for weather: WeatherResponse?) -> [ChartPoint] {
        guard let days = weather?.weather else { return [] }
        var points: [ChartPoint] = []
        for day in days {
            guard let dateString = day.date,
                  let baseDate = dateParser.date(from: dateString)
            else { continue }

            for entry in day.hourly ?? [] {
                guard let hour = entry.hour,
                      let pointDate = Calendar.current.date(byAdding: .hour, value: hour, to: baseDate)
                else { continue }

                let rawTemp = useMetric ? entry.tempC : entry.tempF
                points.append(ChartPoint(
                    id: pointDate,
                    date: pointDate,
                    temperature: rawTemp.flatMap { Double($0) },
                    precipChance: Int(entry.chanceofrain ?? "") ?? 0
                ))
            }
        }
        return points
    }

    func moonItems(for weather: WeatherResponse?) -> [MoonItem] {
        guard let days = weather?.weather, !days.isEmpty else { return [] }
        var items: [MoonItem] = []
        for (index, day) in days.prefix(3).enumerated() {
            let title = dayTitle(index: index, dateString: day.date)
            let date = day.date.flatMap { dateParser.date(from: $0) } ?? Date()
            let moonState = LunarPhaseEngine.calculate(for: date)
            let rawPhaseName = (day.astronomy?.first?.moonPhase?.isEmpty == false) ? (day.astronomy?.first?.moonPhase ?? moonState.phaseName) : moonState.phaseName
            let localizedPhase = WeatherIconMapper.localizedMoonPhaseName(for: rawPhaseName)
            let symbol = WeatherIconMapper.moonPhaseSymbol(for: rawPhaseName)
            let illum = (day.astronomy?.first?.moonIllumination?.isEmpty == false) ? (day.astronomy?.first?.moonIllumination ?? "\(moonState.illuminationPercent)") : "\(moonState.illuminationPercent)"

            items.append(MoonItem(
                id: "\(day.date ?? UUID().uuidString)-\(index)",
                title: title,
                phaseSymbol: symbol,
                phaseName: localizedPhase,
                illuminationText: "\(illum)%"
            ))
        }
        return items
    }

    func dayItems(for weather: WeatherResponse?) -> [DayItem] {
        guard let days = weather?.weather else { return [] }
        return days.prefix(3).enumerated().map { index, day in
            let dateString = day.date
            let title = dayTitle(index: index, dateString: dateString)
            let precip = (day.hourly ?? []).compactMap { Int($0.chanceofrain ?? "") }.max() ?? 0
            let representative = (day.hourly ?? []).first { $0.hour == 12 }
                ?? (day.hourly ?? []).first

            let minVal = Double(useMetric ? (day.mintempC ?? "0") : (day.mintempF ?? "0")) ?? 0
            let maxVal = Double(useMetric ? (day.maxtempC ?? "0") : (day.maxtempF ?? "0")) ?? 0

            let minC = Double(day.mintempC ?? "0") ?? 0
            let maxC = Double(day.maxtempC ?? "0") ?? 0

            return DayItem(
                id: dateString ?? "day-\(index)",
                title: title,
                symbol: WeatherIconMapper.symbol(for: representative?.weatherCode, isDay: true),
                minText: tempString(day.mintempC, day.mintempF),
                maxText: tempString(day.maxtempC, day.maxtempF),
                minValue: minVal,
                maxValue: maxVal,
                minTempC: minC,
                maxTempC: maxC,
                precipChance: precip,
                isToday: (index == 0)
            )
        }
    }

    func upcomingHours(for weather: WeatherResponse?) -> [HourlyItem] {
        guard let days = weather?.weather else { return [] }
        let currentHour = Calendar.current.component(.hour, from: Date())
        var hours: [HourlyItem] = []
        for (dayIndex, day) in days.prefix(2).enumerated() {
            for entry in day.hourly ?? [] {
                guard let hour = entry.hour else { continue }
                if dayIndex == 0 && hour < currentHour { continue }
                hours.append(HourlyItem(
                    id: "\(dayIndex)-\(hour)",
                    hourText: String(format: "%02d:00", hour),
                    symbol: WeatherIconMapper.symbol(for: entry.weatherCode, isDay: (6..<21).contains(hour)),
                    tempText: tempString(entry.tempC, entry.tempF),
                    precipChance: Int(entry.chanceofrain ?? "") ?? 0
                ))
                if hours.count == 8 { break }
            }
            if hours.count == 8 { break }
        }
        return hours
    }

    // MARK: - Helpers

    private func dayTitle(index: Int, dateString: String?) -> String {
        if index == 0 {
            return String(localized: "Today")
        }
        if let dateString, let date = dateParser.date(from: dateString) {
            return weekdayFormatter.string(from: date)
        }
        return dateString ?? "\(String(localized: "Day")) \(index + 1)"
    }

    // MARK: - Formatting helpers

    func tempString(_ c: String?, _ f: String?) -> String {
        guard let value = useMetric ? c : f, !value.isEmpty else { return "--°" }
        return "\(value)°"
    }

    private func windString(_ kmph: String?, _ mph: String?, dir: String?) -> String {
        let speed = useMetric ? kmph.map { "\($0) km/h" } : mph.map { "\($0) mph" }
        return [speed, dir].compactMap { $0 }.joined(separator: " ")
    }

    private func uvString(_ c: CurrentCondition, today: DayForecast?) -> String {
        if let uv = c.uvIndex, !uv.isEmpty && uv != "—" {
            return uv
        }
        if let dayUv = today?.uvIndex, !dayUv.isEmpty && dayUv != "—" {
            return dayUv
        }
        return "—"
    }

    private func pressureString(_ c: CurrentCondition) -> String {
        if useMetric {
            if let p = c.pressure, !p.isEmpty { return "\(p) hPa" }
            if let pin = c.pressureInches, let val = Double(pin) {
                return "\(Int(round(val / 0.0295299830714))) hPa"
            }
            return "—"
        } else {
            if let pin = c.pressureInches, !pin.isEmpty { return "\(pin) inHg" }
            if let p = c.pressure, let val = Double(p) {
                return String(format: "%.2f inHg", val * 0.0295299830714)
            }
            return "—"
        }
    }

    private func visibilityString(_ c: CurrentCondition) -> String {
        if useMetric {
            if let v = c.visibility, !v.isEmpty { return "\(v) km" }
            if let vm = c.visibilityMiles, let val = Double(vm) {
                return String(format: "%.0f km", round(val * 1.609344))
            }
            return "—"
        } else {
            if let vm = c.visibilityMiles, !vm.isEmpty { return "\(vm) mi" }
            if let v = c.visibility, let val = Double(v) {
                return String(format: "%.0f mi", round(val / 1.609344))
            }
            return "—"
        }
    }

    private func precipString(_ c: CurrentCondition) -> String {
        if useMetric {
            if let p = c.precipMM, !p.isEmpty { return "\(p) mm" }
            if let pin = c.precipInches, let val = Double(pin) {
                return String(format: "%.1f mm", val * 25.4)
            }
            return "—"
        } else {
            if let pin = c.precipInches, !pin.isEmpty { return "\(pin) in" }
            if let p = c.precipMM, let val = Double(p) {
                return String(format: "%.2f in", val * 0.03937007874)
            }
            return "—"
        }
    }

    private static func minutes(from12h string: String?) -> Int? {
        guard let string else { return nil }
        let parts = string.split(separator: " ")
        guard parts.count == 2 else { return nil }
        let hm = parts[0].split(separator: ":")
        guard hm.count == 2, let h = Int(hm[0]), let m = Int(hm[1]) else { return nil }
        let isPM = parts[1].uppercased() == "PM"
        return ((h % 12) + (isPM ? 12 : 0)) * 60 + m
    }

    // MARK: - Solar & Shadow Spatial Intelligence

    /// Resolves best available geographical coordinates for a page item.
    func coordinate(for page: WeatherPageItem) -> CLLocationCoordinate2D {
        if page.isGPS {
            if let lat = automaticLatitude, let lon = automaticLongitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        if let lat = page.latitude, let lon = page.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let weather = weather(for: page.id),
           let nearest = weather.nearestArea?.first,
           let latStr = nearest.latitude, let lat = Double(latStr),
           let lonStr = nearest.longitude, let lon = Double(lonStr) {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900)
    }

    /// Evaluates current solar & shadow spatial metrics for a page item at an optional target date.
    func solarState(for page: WeatherPageItem, date: Date = Date()) -> SolarShadowEngine.State {
        let coord = coordinate(for: page)
        let w = weather(for: page.id) ?? weather
        let cloudCover = Int(w?.currentCondition?.first?.cloudcover ?? "0") ?? 0
        let uv = Int(w?.currentCondition?.first?.uvIndex ?? "0") ?? 0
        let tempC = Double(w?.currentCondition?.first?.tempC ?? "")

        return SolarShadowEngine.evaluate(
            coordinate: coord,
            date: date,
            cloudCoverPercent: cloudCover,
            uvIndex: uv,
            temperatureC: tempC
        )
    }
}
