import Foundation
import UserNotifications

/// Local weather notifications (daily summary + rain alert). No push server.
@MainActor
enum NotificationManager {
    static let dailySummaryIdentifier = "weather.dailySummary"
    static let rainAlertIdentifier = "weather.rainAlert"
    static let rainThreshold = 60

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(
        weather: WeatherResponse?,
        useMetric: Bool,
        dailyEnabled: Bool,
        dailyHour: Int,
        rainAlertEnabled: Bool
    ) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(
            withIdentifiers: [dailySummaryIdentifier, rainAlertIdentifier]
        )

        let settings = await center.notificationSettings()
        let allowed = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        guard allowed else { return }

        if dailyEnabled {
            var components = DateComponents()
            components.hour = dailyHour
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = String(localized: "DeepWeather")
            content.body = dailySummaryBody(weather: weather, useMetric: useMetric)
            content.sound = .default
            try? await center.add(UNNotificationRequest(
                identifier: dailySummaryIdentifier,
                content: content,
                trigger: trigger
            ))
        }

        if rainAlertEnabled, let rain = rainChanceTomorrow(weather: weather), rain >= rainThreshold {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 19
            components.minute = 0

            // Schedule for today at 19:00 if not already passed, without infinite daily repetition
            if let targetDate = calendar.date(from: components), targetDate > Date() {
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let content = UNMutableNotificationContent()
                content.title = String(localized: "DeepWeather")
                content.body = "\(String(localized: "Rain likely tomorrow. Remember an umbrella.")) \(rain)%."
                content.sound = .default
                try? await center.add(UNNotificationRequest(
                    identifier: rainAlertIdentifier,
                    content: content,
                    trigger: trigger
                ))
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [dailySummaryIdentifier, rainAlertIdentifier]
        )
    }

    // MARK: - Helpers

    static func dailySummaryBody(weather: WeatherResponse?, useMetric: Bool) -> String {
        guard let day = weather?.weather?.first else {
            return String(localized: "Open DeepWeather to see today's forecast.")
        }
        let representative = (day.hourly ?? []).first { $0.hour == 12 }
            ?? (day.hourly ?? []).first
        let condition = representative?.conditionDescription ?? String(localized: "Weather")
        let min = tempString(day.mintempC, day.mintempF, useMetric: useMetric)
        let max = tempString(day.maxtempC, day.maxtempF, useMetric: useMetric)
        let rain = (day.hourly ?? []).compactMap { Int($0.chanceofrain ?? "") }.max() ?? 0
        return "\(condition). \(String(localized: "Min")) \(min), \(String(localized: "max")) \(max). \(String(localized: "Rain chance")) \(rain)%."
    }

    static func rainChanceTomorrow(weather: WeatherResponse?) -> Int? {
        guard weather?.weather?.count ?? 0 >= 2, let tomorrow = weather?.weather?[1] else {
            return nil
        }
        return (tomorrow.hourly ?? []).compactMap { Int($0.chanceofrain ?? "") }.max()
    }

    static func tempString(_ c: String?, _ f: String?, useMetric: Bool) -> String {
        guard let value = useMetric ? c : f, !value.isEmpty else { return "--°" }
        return "\(value)°"
    }
}
