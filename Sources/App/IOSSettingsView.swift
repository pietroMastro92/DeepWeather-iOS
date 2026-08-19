import SwiftUI

struct IOSSettingsView: View {
    @Bindable var store: WeatherStore
    var locationManager: LocationManager

    @Environment(\.dismiss) private var dismiss
    @State private var showSearch = false
    @State private var showResetSetupAlert = false
    @State private var isManualRefreshing = false
    @State private var showDemoShowcase = false

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                demoShowcaseSection
                locationSection
                providerSection
                unitsSection
                refreshSection
                notificationSection
                setupSection
                aboutSection
            }
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
            .sheet(isPresented: $showSearch) {
                IOSLocationSearchView(store: store)
            }
            .fullScreenCover(isPresented: $showDemoShowcase) {
                WeatherAnimationShowcaseView()
            }
            .alert(String(localized: "Restart initial setup"), isPresented: $showResetSetupAlert) {
                Button(String(localized: "Cancel"), role: .cancel) {}
                Button(String(localized: "Restart"), role: .destructive) {
                    dismiss()
                    store.resetOnboarding()
                }
            } message: {
                Text(String(localized: "Would you like to restart the onboarding flow to reconfigure your location and preferences?"))
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.35, green: 0.62, blue: 0.95),
                                    Color(red: 0.15, green: 0.40, blue: 0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "cloud.sun.fill")
                        .renderingMode(.original)
                        .font(.system(size: 30))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("DeepWeather")
                        .font(.headline.weight(.bold))
                    Text("Weather, beautifully animated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("v1.0 (Build 1) • Local-first")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Demo Showcase Section

    private var demoShowcaseSection: some View {
        Section {
            Button {
                showDemoShowcase = true
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(symbol: "sparkles.tv", color: .purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Showcase Animazioni Meteo")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Valida e ispeziona tutte le 9 condizioni fotorealistiche")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Demo & Validazione")
        } footer: {
            Text("Esplora e valida tutte le modalità meteo con controlli in tempo reale e simulatore di movimento.")
        }
    }

    // MARK: - Location Section

    private var locationSection: some View {
        Section {
            // GPS Location
            Button {
                locationManager.requestWhenInUse()
                store.resetToAutomaticLocation()
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(symbol: "location.fill", color: .blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Automatic (GPS)"))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                        Text(String(localized: "Uses your current GPS coordinates"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if store.selectedLocationID == nil && store.isAutomaticGPSActive {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }

            // Saved Cities List with Reordering & Deletion
            ForEach(store.savedLocations) { location in
                Button {
                    store.selectSavedLocation(location.id)
                } label: {
                    HStack(spacing: 12) {
                        SettingsIconBadge(symbol: "building.2.fill", color: .indigo)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            if !location.detail.isEmpty {
                                Text(location.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if location.id == store.selectedLocationID {
                            Image(systemName: "checkmark")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    let id = store.savedLocations[index].id
                    store.removeLocation(id: id)
                }
            }
            .onMove { source, destination in
                store.moveLocations(from: source, to: destination)
            }

            // Add city button
            Button {
                showSearch = true
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(symbol: "plus", color: .green)
                    Text(String(localized: "Add city"))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.tint)
                }
            }
        } header: {
            HStack {
                Text(String(localized: "Location"))
                Spacer()
                if !store.savedLocations.isEmpty {
                    EditButton()
                        .font(.caption.weight(.medium))
                }
            }
        } footer: {
            Text(String(localized: "Swipe to delete or drag to reorder your saved locations."))
        }
    }

    // MARK: - Weather Provider Section

    private var providerSection: some View {
        Section {
            Picker(String(localized: "Provider"), selection: $store.weatherProvider) {
                ForEach(WeatherProvider.allCases) { prov in
                    Text(prov.displayName).tag(prov)
                }
            }
            .pickerStyle(.menu)

            HStack(spacing: 12) {
                SettingsIconBadge(symbol: "cloud.rainbow.half", color: .indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.weatherProvider.displayName)
                        .font(.subheadline.weight(.medium))
                    Text(store.weatherProvider.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "Weather Data Source"))
        } footer: {
            Text(String(localized: "Auto mode uses direct national meteorological models with automatic data anomaly protection and failover."))
        }
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        Section {
            Picker(String(localized: "Units"), selection: $store.useMetric) {
                Text(String(localized: "Metric (°C, km/h)")).tag(true)
                Text(String(localized: "Imperial (°F, mph)")).tag(false)
            }
            .pickerStyle(.segmented)

            HStack {
                SettingsIconBadge(symbol: "ruler.fill", color: .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.useMetric ? String(localized: "Metric system") : String(localized: "Imperial system"))
                        .font(.subheadline.weight(.medium))
                    Text(store.useMetric ? "°C, km/h, mm, hPa, km" : "°F, mph, in, inHg, mi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(String(localized: "Units"))
        }
    }

    // MARK: - Refresh Section

    private var refreshSection: some View {
        Section {
            Picker(String(localized: "Refresh interval"), selection: $store.refreshIntervalMinutes) {
                Text("10 \(String(localized: "min"))").tag(10)
                Text("15 \(String(localized: "min"))").tag(15)
                Text("30 \(String(localized: "min"))").tag(30)
                Text("60 \(String(localized: "min"))").tag(60)
            }
            .pickerStyle(.segmented)

            Button {
                performManualRefresh()
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(symbol: "arrow.clockwise", color: .teal)

                    Text(String(localized: "Refresh now"))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    if isManualRefreshing {
                        ProgressView()
                            .scaleEffect(0.85)
                    } else if let last = store.lastUpdated {
                        Text(last.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(isManualRefreshing)
        } header: {
            Text(String(localized: "Refresh interval"))
        }
    }

    // MARK: - Notifications Section

    @ViewBuilder
    private var notificationSection: some View {
        Section {
            Toggle(isOn: dailySummaryBinding) {
                HStack(spacing: 12) {
                    SettingsIconBadge(symbol: "sun.horizon.fill", color: .yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Daily summary"))
                            .font(.body.weight(.medium))
                        Text(String(localized: "Morning weather forecast notification"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if store.dailySummaryEnabled {
                DatePicker(
                    String(localized: "Time"),
                    selection: summaryTimeBinding,
                    displayedComponents: .hourAndMinute
                )
            }

            Toggle(isOn: rainAlertBinding) {
                HStack(spacing: 12) {
                    SettingsIconBadge(symbol: "cloud.rain.fill", color: .cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Rain alert"))
                            .font(.body.weight(.medium))
                        Text(String(localized: "Rain likely tomorrow. Remember an umbrella."))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text(String(localized: "Notifications"))
        } footer: {
            Text(String(localized: "Weather notifications are scheduled on this device only."))
        }
    }

    // MARK: - Setup Section

    private var setupSection: some View {
        Section {
            Button(role: .destructive) {
                showResetSetupAlert = true
            } label: {
                HStack(spacing: 12) {
                    SettingsIconBadge(symbol: "arrow.counterclockwise", color: .purple)
                    Text(String(localized: "Restart initial setup"))
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
        } header: {
            Text(String(localized: "Setup"))
        } footer: {
            Text(String(localized: "Reconfigure your primary location and preferences."))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section(String(localized: "Information")) {
            LabeledContent(String(localized: "Weather data"), value: "Open-Meteo & Wttr.in")
            LabeledContent(String(localized: "Geocoding"), value: "Apple MapKit")
            LabeledContent(String(localized: "Privacy"), value: "Zero analytics / No tracking")
        }
    }

    // MARK: - Bindings & Actions

    private func performManualRefresh() {
        isManualRefreshing = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            if store.selectedLocationID == nil && store.isAutomaticGPSActive {
                if let coordinate = await locationManager.requestLocation(forceFresh: true) {
                    store.setAutomaticCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
            await store.refresh()
            await rescheduleNotifications()
            isManualRefreshing = false
        }
    }

    private var dailySummaryBinding: Binding<Bool> {
        Binding(
            get: { store.dailySummaryEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        guard granted else { return }
                        store.dailySummaryEnabled = true
                        await rescheduleNotifications()
                    }
                } else {
                    store.dailySummaryEnabled = false
                    Task { await rescheduleNotifications() }
                }
            }
        )
    }

    private var rainAlertBinding: Binding<Bool> {
        Binding(
            get: { store.rainAlertEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await NotificationManager.requestAuthorization()
                        guard granted else { return }
                        store.rainAlertEnabled = true
                        await rescheduleNotifications()
                    }
                } else {
                    store.rainAlertEnabled = false
                    Task { await rescheduleNotifications() }
                }
            }
        )
    }

    private var summaryTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: store.dailySummaryHour,
                    minute: 0,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                store.dailySummaryHour = Calendar.current.component(.hour, from: newValue)
                Task { await rescheduleNotifications() }
            }
        )
    }

    private func rescheduleNotifications() async {
        await NotificationManager.reschedule(
            weather: store.weather,
            useMetric: store.useMetric,
            dailyEnabled: store.dailySummaryEnabled,
            dailyHour: store.dailySummaryHour,
            rainAlertEnabled: store.rainAlertEnabled
        )
    }
}

// MARK: - Reusable Settings Icon Badge

private struct SettingsIconBadge: View {
    let symbol: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.gradient)
                .frame(width: 28, height: 28)

            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
