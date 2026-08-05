import Foundation
import Observation

@MainActor
@Observable
final class WeatherStore {

    // MARK: - View models

    struct DetailItem: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let value: String
    }

    struct HourlyItem: Identifiable {
        let id: String
        let hourText: String
        let symbol: String
        let tempText: String
        let precipChance: Int
    }

    struct DayItem: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let minText: String
        let maxText: String
        let precipChance: Int
    }

    struct ChartPoint: Identifiable {
        let id: Date
        let date: Date
        let temperature: Double?
        let precipChance: Int
    }

    struct MoonItem: Identifiable {
        let id: String
        let title: String
        let phaseSymbol: String
        let phaseName: String
        let illuminationText: String
    }

    // MARK: - State

    private(set) var weather: WeatherResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    private(set) var savedLocations: [SavedLocation] = [] {
        didSet { persistSettings() }
    }

    var selectedLocationID: String? = nil {
        didSet { persistSettings() }
    }

    var useMetric: Bool = true {
        didSet { persistSettings() }
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

    /// Local profile: optional user name shown in the app.
    var userName: String? {
        didSet { persistSettings() }
    }

    /// Whether the welcome screen has been completed (the name is optional).
    private(set) var isOnboarded: Bool = false {
        didSet { persistSettings() }
    }

    /// Dynamic color theme derived from the current weather.
    var theme: WeatherTheme {
        WeatherTheme.for(
            weatherCode: weather?.currentCondition?.first?.weatherCode,
            isDay: isDay
        )
    }

    /// Coordinates reported by CoreLocation when in automatic (no saved city) mode.
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

    // MARK: - Init

    init(client: WeatherClient = WeatherClient()) {
        self.client = client
        self.defaults = AppGroup.defaults

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        self.dateParser = parser

        let weekday = DateFormatter()
        weekday.locale = Locale(identifier: "en_US")
        weekday.dateFormat = "EEE"
        self.weekdayFormatter = weekday

        // All didSet-backed properties have declaration defaults, so every
        // assignment below already has a fully initialized `self`.
        self.useMetric = defaults.object(forKey: Self.useMetricKey) as? Bool ?? true
        self.refreshIntervalMinutes = defaults.object(forKey: Self.refreshIntervalKey) as? Int ?? 15
        self.dailySummaryEnabled = defaults.object(forKey: Self.dailySummaryEnabledKey) as? Bool ?? false
        self.dailySummaryHour = defaults.object(forKey: Self.dailySummaryHourKey) as? Int ?? 8
        self.rainAlertEnabled = defaults.object(forKey: Self.rainAlertEnabledKey) as? Bool ?? false
        self.userName = defaults.string(forKey: Self.userNameKey)
        self.isOnboarded = defaults.bool(forKey: Self.isOnboardedKey)

        if let data = defaults.data(forKey: Self.savedLocationsKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            self.savedLocations = decoded
        } else if let data = defaults.data(forKey: Self.legacySavedLocationKey),
                  let legacy = SavedLocationMigration.legacy(from: data) {
            self.savedLocations = [legacy]
            defaults.removeObject(forKey: Self.legacySavedLocationKey)
        }

        let selectedID = defaults.string(forKey: Self.selectedLocationKey)
        if let selectedID, savedLocations.contains(where: { $0.id == selectedID }) {
            self.selectedLocationID = selectedID
        } else {
            defaults.removeObject(forKey: Self.selectedLocationKey)
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
    private static let userNameKey = "weatherbar.userName"
    private static let isOnboardedKey = "weatherbar.isOnboarded"

    // MARK: - Onboarding / profile

    @MainActor
    func completeWelcome(name: String?) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        userName = (trimmed?.isEmpty ?? true) ? nil : trimmed
        isOnboarded = true
    }

    @MainActor
    func signOut() {
        userName = nil
        isOnboarded = false
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
        selectedLocationID = id
        applySettings()
    }

    @MainActor
    func removeLocation(id: String) {
        savedLocations.removeAll { $0.id == id }
        if selectedLocationID == id {
            selectedLocationID = savedLocations.first?.id
        }
        applySettings()
    }

    @MainActor
    func resetToAutomaticLocation() {
        selectSavedLocation(nil)
    }

    // MARK: - Fetching

    @MainActor
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let query: String?
            if let selected = selectedLocation {
                query = String(format: "%.5f,%.5f", selected.latitude, selected.longitude)
            } else if let automaticLatitude, let automaticLongitude {
                query = String(format: "%.5f,%.5f", automaticLatitude, automaticLongitude)
            } else {
                query = nil
            }
            weather = try await client.fetch(location: query)
            lastUpdated = Date()
            saveSnapshot()
        } catch {
            errorMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        if let clientError = error as? WeatherClient.ClientError {
            return clientError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection."
            case .timedOut:
                return "Request timed out."
            default:
                break
            }
        }
        return "Couldn't read the weather data."
    }

    // MARK: - Persistence

    private func persistSettings() {
        defaults.set(useMetric, forKey: Self.useMetricKey)
        defaults.set(refreshIntervalMinutes, forKey: Self.refreshIntervalKey)
        defaults.set(dailySummaryEnabled, forKey: Self.dailySummaryEnabledKey)
        defaults.set(dailySummaryHour, forKey: Self.dailySummaryHourKey)
        defaults.set(rainAlertEnabled, forKey: Self.rainAlertEnabledKey)
        defaults.set(isOnboarded, forKey: Self.isOnboardedKey)
        if let userName {
            defaults.set(userName, forKey: Self.userNameKey)
        } else {
            defaults.removeObject(forKey: Self.userNameKey)
        }
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
        snapshot.latitude = automaticLatitude
        snapshot.longitude = automaticLongitude
        snapshot.dailySummaryEnabled = dailySummaryEnabled
        snapshot.dailySummaryHour = dailySummaryHour
        snapshot.rainAlertEnabled = rainAlertEnabled
        snapshot.save(to: defaults)
    }

    // MARK: - Current conditions

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
        let raw = useMetric
            ? weather?.currentCondition?.first?.tempC
            : weather?.currentCondition?.first?.tempF
        return raw.flatMap { Double($0) }
    }

    var currentTempText: String {
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
        return weather?.nearestArea?.first?.areaName?.first?.value ?? "Current location"
    }

    var locationDetail: String {
        if let selected = selectedLocation, !selected.detail.isEmpty {
            return selected.detail
        }
        guard let area = weather?.nearestArea?.first else { return "" }
        return [area.region?.first?.value, area.country?.first?.value]
            .compactMap { $0 }.joined(separator: ", ")
    }

    var currentConditionText: String {
        weather?.currentCondition?.first?.conditionDescription ?? ""
    }

    var isDay: Bool {
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

    var detailItems: [DetailItem] {
        guard let c = weather?.currentCondition?.first else { return [] }
        let astro = weather?.weather?.first?.astronomy?.first
        var items = [
            DetailItem(id: "feels", symbol: "thermometer.medium", title: "Feels like", value: tempString(c.feelsLikeC, c.feelsLikeF)),
            DetailItem(id: "humidity", symbol: "humidity", title: "Humidity", value: c.humidity.map { "\($0)%" } ?? "—"),
            DetailItem(id: "wind", symbol: "wind", title: "Wind", value: windString(c.windspeedKmph, c.windspeedMiles, dir: c.winddir16Point)),
            DetailItem(id: "uv", symbol: "sun.max", title: "UV index", value: c.uvIndex ?? "—"),
            DetailItem(id: "pressure", symbol: "gauge", title: "Pressure", value: pressureString(c)),
            DetailItem(id: "visibility", symbol: "eye", title: "Visibility", value: visibilityString(c)),
            DetailItem(id: "precipitation", symbol: "drop", title: "Precipitation", value: precipString(c)),
            DetailItem(id: "cloudcover", symbol: "cloud", title: "Cloud cover", value: c.cloudcover.map { "\($0)%" } ?? "—")
        ]
        if let sunrise = astro?.sunrise {
            items.append(DetailItem(id: "sunrise", symbol: "sunrise", title: "Sunrise", value: sunrise))
        }
        if let sunset = astro?.sunset {
            items.append(DetailItem(id: "sunset", symbol: "sunset", title: "Sunset", value: sunset))
        }
        if let moonrise = astro?.moonrise {
            items.append(DetailItem(id: "moonrise", symbol: "moonrise", title: "Moonrise", value: moonrise))
        }
        if let moonset = astro?.moonset {
            items.append(DetailItem(id: "moonset", symbol: "moonset", title: "Moonset", value: moonset))
        }
        return items
    }

    // MARK: - Charts

    var chartMidnights: [Date] {
        guard let days = weather?.weather else { return [] }
        return days.compactMap { day in
            day.date.flatMap { dateParser.date(from: $0) }
        }
    }

    var chartPoints: [ChartPoint] {
        guard let days = weather?.weather else { return [] }
        let calendar = Calendar.current
        var points: [ChartPoint] = []
        for day in days {
            guard let dateString = day.date, let baseDate = dateParser.date(from: dateString) else { continue }
            for entry in day.hourly ?? [] {
                guard let hour = entry.hour,
                      let date = calendar.date(byAdding: .hour, value: hour, to: baseDate)
                else { continue }
                let rawTemp = useMetric ? entry.tempC : entry.tempF
                points.append(ChartPoint(
                    id: date,
                    date: date,
                    temperature: rawTemp.flatMap { Double($0) },
                    precipChance: Int(entry.chanceofrain ?? "") ?? 0
                ))
            }
        }
        return points
    }

    // MARK: - Moon

    var moonItems: [MoonItem] {
        guard let days = weather?.weather else { return [] }
        return days.enumerated().map { index, day in
            let astro = day.astronomy?.first
            let dateString = day.date
            let title = dayTitle(index: index, dateString: dateString)
            let phaseName = astro?.moonPhase ?? "—"
            return MoonItem(
                id: dateString ?? "day-\(index)",
                title: title,
                phaseSymbol: WeatherIconMapper.moonPhaseSymbol(for: astro?.moonPhase),
                phaseName: phaseName,
                illuminationText: astro?.moonIllumination.map { "\($0)%" } ?? "—"
            )
        }
    }

    // MARK: - Hourly

    var upcomingHours: [HourlyItem] {
        guard let days = weather?.weather, !days.isEmpty else { return [] }
        let currentHour = Calendar.current.component(.hour, from: Date())
        var result: [HourlyItem] = []

        for (dayIndex, day) in days.prefix(2).enumerated() {
            for entry in day.hourly ?? [] {
                guard let hour = entry.hour else { continue }
                if dayIndex == 0 && hour < currentHour { continue }
                result.append(HourlyItem(
                    id: "\(dayIndex)-\(hour)",
                    hourText: String(format: "%02d:00", hour),
                    symbol: WeatherIconMapper.symbol(for: entry.weatherCode, isDay: (6..<21).contains(hour)),
                    tempText: tempString(entry.tempC, entry.tempF),
                    precipChance: Int(entry.chanceofrain ?? "") ?? 0
                ))
                if result.count == 8 { return result }
            }
        }
        return result
    }

    // MARK: - Days

    var dayItems: [DayItem] {
        guard let days = weather?.weather else { return [] }
        return days.enumerated().map { index, day in
            let dateString = day.date
            let title = dayTitle(index: index, dateString: dateString)
            let precip = (day.hourly ?? []).compactMap { Int($0.chanceofrain ?? "") }.max() ?? 0
            let representative = (day.hourly ?? []).first { $0.hour == 12 }
                ?? (day.hourly ?? []).first

            return DayItem(
                id: dateString ?? "day-\(index)",
                title: title,
                symbol: WeatherIconMapper.symbol(for: representative?.weatherCode, isDay: true),
                minText: tempString(day.mintempC, day.mintempF),
                maxText: tempString(day.maxtempC, day.maxtempF),
                precipChance: precip
            )
        }
    }

    // MARK: - Helpers

    private func dayTitle(index: Int, dateString: String?) -> String {
        if index == 0 {
            return "Today"
        }
        if let dateString, let date = dateParser.date(from: dateString) {
            return weekdayFormatter.string(from: date)
        }
        return dateString ?? "Day \(index + 1)"
    }

    // MARK: - Formatting helpers

    private func tempString(_ c: String?, _ f: String?) -> String {
        guard let value = useMetric ? c : f, !value.isEmpty else { return "--°" }
        return "\(value)°"
    }

    private func windString(_ kmph: String?, _ mph: String?, dir: String?) -> String {
        let speed = useMetric ? kmph.map { "\($0) km/h" } : mph.map { "\($0) mph" }
        return [speed, dir].compactMap { $0 }.joined(separator: " ")
    }

    private func pressureString(_ c: CurrentCondition) -> String {
        useMetric
            ? c.pressure.map { "\($0) hPa" } ?? "—"
            : c.pressureInches.map { "\($0) inHg" } ?? "—"
    }

    private func visibilityString(_ c: CurrentCondition) -> String {
        useMetric
            ? c.visibility.map { "\($0) km" } ?? "—"
            : c.visibilityMiles.map { "\($0) mi" } ?? "—"
    }

    private func precipString(_ c: CurrentCondition) -> String {
        useMetric
            ? c.precipMM.map { "\($0) mm" } ?? "—"
            : c.precipInches.map { "\($0) in" } ?? "—"
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
}
