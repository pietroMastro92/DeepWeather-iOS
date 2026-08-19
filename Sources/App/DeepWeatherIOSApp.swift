import SwiftUI

@main
struct DeepWeatherIOSApp: App {
    @State private var store = WeatherStore()
    @State private var locationManager = LocationManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("-showDemoShowcase") || ProcessInfo.processInfo.arguments.contains("-demoScene") {
                    WeatherAnimationShowcaseView()
                } else if !store.isOnboarded {
                    OnboardingWizardView(store: store, locationManager: locationManager)
                } else {
                    DashboardView(store: store, locationManager: locationManager)
                }
            }
            .task { await boot() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, store.isOnboarded else { return }
                Task { await refreshWeather() }
            }
        }
    }

    @MainActor
    private func boot() async {
        store.startAutoRefresh(immediately: false)
        if store.isOnboarded {
            await refreshWeather()
        }
    }

    @MainActor
    private func refreshWeather() async {
        // Only request GPS if the user explicitly chose automatic GPS mode
        if store.selectedLocationID == nil && store.isAutomaticGPSActive {
            if let coordinate = await locationManager.requestLocation(forceFresh: true) {
                store.setAutomaticCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
            }
        }
        await store.refresh()
        await NotificationManager.reschedule(
            weather: store.weather,
            useMetric: store.useMetric,
            dailyEnabled: store.dailySummaryEnabled,
            dailyHour: store.dailySummaryHour,
            rainAlertEnabled: store.rainAlertEnabled
        )
    }
}
