import SwiftUI

struct DashboardView: View {
    @Bindable var store: WeatherStore
    var locationManager: LocationManager

    @State private var showSettings = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isWide: Bool { horizontalSizeClass == .regular }

    var body: some View {
        NavigationStack {
            content
                .background(Color(.systemGroupedBackground))
                .navigationTitle(store.locationName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(String(localized: "Settings"))
                    }
                }
                .refreshable { await refresh() }
                .sheet(isPresented: $showSettings) {
                    IOSSettingsView(store: store, locationManager: locationManager)
                }
                .task {
                    if store.weather == nil { await refresh() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.weather != nil {
            ScrollView {
                Group {
                    if isWide {
                        wideLayout
                    } else {
                        narrowLayout
                    }
                }
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        } else if let message = store.errorMessage {
            ContentUnavailableView {
                Label(String(localized: "Couldn't load weather"), systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button(String(localized: "Retry")) {
                    Task { await refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ProgressView(String(localized: "Loading weather…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Single column (iPhone / compact)

    private var narrowLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            currentConditionsCard
            if store.weather != nil, let message = store.errorMessage {
                ErrorBannerView(message: message)
            }
            EntranceCardView(index: 1) {
                DetailGridView(items: store.detailItems)
            }
            EntranceCardView(index: 2) {
                TemperatureChartView(
                    points: store.chartPoints,
                    midnights: store.chartMidnights,
                    now: Date(),
                    unitSymbol: store.temperatureUnitSymbol,
                    observedTemp: store.currentTempValue,
                    accent: store.theme.accent
                )
            }
            EntranceCardView(index: 3) {
                PrecipitationChartView(
                    points: store.chartPoints,
                    midnights: store.chartMidnights,
                    accent: store.theme.accent
                )
            }
            EntranceCardView(index: 4) {
                MoonPhaseView(items: store.moonItems)
            }
            EntranceCardView(index: 5) {
                HourlyStripView(items: store.upcomingHours)
            }
            EntranceCardView(index: 6) {
                ForecastListView(items: store.dayItems)
            }
        }
    }

    // MARK: - Two columns (iPad / regular)

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                currentConditionsCard
                if store.weather != nil, let message = store.errorMessage {
                    ErrorBannerView(message: message)
                }
                EntranceCardView(index: 1) {
                    DetailGridView(items: store.detailItems)
                }
                EntranceCardView(index: 2) {
                    MoonPhaseView(items: store.moonItems)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                EntranceCardView(index: 3) {
                    TemperatureChartView(
                        points: store.chartPoints,
                        midnights: store.chartMidnights,
                        now: Date(),
                        unitSymbol: store.temperatureUnitSymbol,
                        observedTemp: store.currentTempValue,
                        accent: store.theme.accent
                    )
                }
                EntranceCardView(index: 4) {
                    PrecipitationChartView(
                        points: store.chartPoints,
                        midnights: store.chartMidnights,
                        accent: store.theme.accent
                    )
                }
                EntranceCardView(index: 5) {
                    HourlyStripView(items: store.upcomingHours)
                }
                EntranceCardView(index: 6) {
                    ForecastListView(items: store.dayItems)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var currentConditionsCard: some View {
        ZStack {
            AnimatedWeatherBackgroundView(
                gradient: store.theme.heroGradient,
                isNight: !store.isDay,
                showsStars: !store.isDay
            )
            .id(themeKey)
            .transition(.opacity)

            CurrentConditionsView(
                locationName: store.locationName,
                locationDetail: store.locationDetail,
                tempText: store.currentTempText,
                conditionText: store.currentConditionText,
                iconName: store.menuBarIcon,
                iconKind: store.menuBarAnimationKind,
                locations: store.savedLocations,
                selectedLocationID: store.selectedLocationID,
                onSelectLocation: { id in
                    store.selectSavedLocation(id)
                },
                onGradient: true
            )
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.easeInOut(duration: 1.2), value: themeKey)
    }

    private var themeKey: String {
        "\(store.weather?.currentCondition?.first?.weatherCode ?? "none")-\(store.isDay)"
    }

    private func refresh() async {
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

private struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

/// Card with a staggered entrance animation (opacity + slide + subtle scale).
private struct EntranceCardView<Content: View>: View {
    let index: Int
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        SectionCard { content }
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .scaleEffect(visible ? 1 : 0.985)
            .onAppear {
                guard !reduceMotion else {
                    visible = true
                    return
                }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.06)) {
                    visible = true
                }
            }
    }
}
