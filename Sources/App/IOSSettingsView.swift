import SwiftUI

struct IOSSettingsView: View {
    @Bindable var store: WeatherStore
    var locationManager: LocationManager

    @Environment(\.dismiss) private var dismiss
    @State private var showSearch = false
    @State private var showEditName = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                locationSection
                unitsSection
                refreshSection
                notificationSection
            }
            .navigationTitle(String(localized: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showSearch) {
                IOSLocationSearchView(store: store)
            }
            .sheet(isPresented: $showEditName) {
                NameEditSheet(store: store)
            }
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            LabeledContent(String(localized: "Name")) {
                Text(store.userName ?? String(localized: "Not set"))
                    .foregroundStyle(store.userName == nil ? .secondary : .primary)
            }
            Button(String(localized: "Edit name")) {
                showEditName = true
            }
            Button(String(localized: "Sign out"), role: .destructive) {
                dismiss()
                store.signOut()
            }
        } header: {
            Text(String(localized: "Profile"))
        } footer: {
            Text(String(localized: "Saved on this device only."))
        }
    }

    // MARK: - Location

    private var locationSection: some View {
        Section(String(localized: "Location")) {
            Button {
                locationManager.requestWhenInUse()
                store.resetToAutomaticLocation()
            } label: {
                HStack {
                    Label(String(localized: "Automatic (GPS)"), systemImage: "location")
                    Spacer()
                    if store.selectedLocationID == nil {
                        Image(systemName: "checkmark").foregroundStyle(.tint)
                    }
                }
            }
            .foregroundStyle(.primary)

            ForEach(store.savedLocations) { location in
                Button {
                    store.selectSavedLocation(location.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(location.name)
                            Text(location.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if location.id == store.selectedLocationID {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .onDelete { offsets in
                for index in offsets {
                    let id = store.savedLocations[index].id
                    store.removeLocation(id: id)
                }
            }

            Button {
                showSearch = true
            } label: {
                Label(String(localized: "Add city"), systemImage: "plus")
            }
        }
    }

    // MARK: - Units & refresh

    private var unitsSection: some View {
        Section(String(localized: "Units")) {
            Picker(String(localized: "Units"), selection: $store.useMetric) {
                Text(String(localized: "Metric (°C, km/h)")).tag(true)
                Text(String(localized: "Imperial (°F, mph)")).tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var refreshSection: some View {
        Section(String(localized: "Refresh interval")) {
            Picker(String(localized: "Refresh"), selection: $store.refreshIntervalMinutes) {
                Text("10 \(String(localized: "min"))").tag(10)
                Text("15 \(String(localized: "min"))").tag(15)
                Text("30 \(String(localized: "min"))").tag(30)
                Text("60 \(String(localized: "min"))").tag(60)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationSection: some View {
        Section(String(localized: "Notifications")) {
            Toggle(String(localized: "Daily summary"), isOn: dailySummaryBinding)
            if store.dailySummaryEnabled {
                DatePicker(
                    String(localized: "Time"),
                    selection: summaryTimeBinding,
                    displayedComponents: .hourAndMinute
                )
            }
            Toggle(String(localized: "Rain alert"), isOn: rainAlertBinding)
            Text(String(localized: "Weather notifications are scheduled on this device only."))
                .font(.caption)
                .foregroundStyle(.secondary)
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

/// Sheet used to edit the local profile name.
private struct NameEditSheet: View {
    @Bindable var store: WeatherStore

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(store: WeatherStore) {
        self._store = Bindable(store)
        _name = State(initialValue: store.userName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "Your name"), text: $name)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle(String(localized: "Edit name"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.userName = trimmed.isEmpty ? nil : trimmed
        dismiss()
    }
}
