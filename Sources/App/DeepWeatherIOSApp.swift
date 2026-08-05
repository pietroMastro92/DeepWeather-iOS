import SwiftUI

@main
struct DeepWeatherIOSApp: App {
    @State private var store = WeatherStore()
    @State private var locationManager = LocationManager()
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SplashView()
                } else if !store.isOnboarded {
                    WelcomeView(store: store)
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
        try? await Task.sleep(for: .milliseconds(1600))
        withAnimation(.easeInOut(duration: 0.4)) { showSplash = false }
        store.startAutoRefresh(immediately: false)
        if store.isOnboarded {
            await refreshWeather()
        }
    }

    @MainActor
    private func refreshWeather() async {
        if store.selectedLocationID == nil {
            if let coordinate = await locationManager.requestLocation() {
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
