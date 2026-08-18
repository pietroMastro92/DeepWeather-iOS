import SwiftUI

struct DashboardView: View {
    // MARK: - Environment & Dependencies
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var store: WeatherStore
    var locationManager: LocationManager

    // MARK: - State
    @State private var selectedPageIndex: Int = 0
    @State private var showSettings = false
    @State private var showAddLocation = false
    @State private var showSunShadowMap = ProcessInfo.processInfo.arguments.contains("-showSunShadowMap")
    @State private var isVerticalScrolling = false

    // MARK: - Computed Properties
    private var isWide: Bool { horizontalSizeClass == .regular }

    private var pages: [WeatherStore.WeatherPageItem] {
        store.allPages
    }

    private var activePage: WeatherStore.WeatherPageItem? {
        guard !pages.isEmpty else { return nil }
        let index = min(max(0, selectedPageIndex), pages.count - 1)
        return pages[index]
    }

    private var activeWeather: WeatherResponse? {
        guard let activePage else { return store.weather }
        return store.weather(for: activePage.id) ?? store.weather
    }

    private var activeTheme: WeatherTheme {
        store.theme(for: activeWeather)
    }

    private var activeIsDay: Bool {
        store.isDay(for: activeWeather)
    }

    private var activeAnimationKind: WeatherAnimationKind {
        WeatherIconMapper.animationKind(
            for: activeWeather?.currentCondition?.first?.weatherCode,
            isDay: activeIsDay
        )
    }

    private var themeKey: String {
        let code = activeWeather?.currentCondition?.first?.weatherCode ?? "none"
        let dayStr = activeIsDay ? "day" : "night"
        let pageId = activePage?.id ?? "default"
        return "\(pageId)-\(code)-\(dayStr)"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                skyBackgroundView
                pagesTabView
                topFloatingBar

                VStack {
                    Spacer()
                    bottomFloatingDock
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                IOSSettingsView(store: store, locationManager: locationManager)
            }
            .sheet(isPresented: $showAddLocation) {
                IOSLocationSearchView(store: store)
            }
            .fullScreenCover(isPresented: $showSunShadowMap) {
                if let activePage {
                    SunShadowMapView(store: store, page: activePage)
                } else if let firstPage = pages.first {
                    SunShadowMapView(store: store, page: firstPage)
                } else {
                    SunShadowMapView(
                        store: store,
                        page: WeatherStore.WeatherPageItem(
                            id: "gps",
                            isGPS: true,
                            name: "Posizione attuale",
                            detail: "Meteo locale",
                            latitude: nil,
                            longitude: nil
                        )
                    )
                }
            }
            .task {
                syncPageIndexFromStore()
                await initialLoad()
                if ProcessInfo.processInfo.arguments.contains("-showSunShadowMap") {
                    showSunShadowMap = true
                }
            }
            .onChange(of: store.selectedLocationID) { _, _ in
                syncPageIndexFromStore()
            }
            .onChange(of: store.isAutomaticGPSActive) { _, _ in
                syncPageIndexFromStore()
            }
            .onChange(of: store.savedLocations.count) { _, _ in
                syncPageIndexFromStore()
            }
        }
    }

    // MARK: - Subviews

    private var skyBackgroundView: some View {
        AnimatedWeatherBackgroundView(
            gradient: activeTheme.heroGradient,
            isNight: !activeIsDay,
            showsStars: !activeIsDay,
            weatherKind: activeAnimationKind
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: themeKey)
    }

    @ViewBuilder
    private var pagesTabView: some View {
        if !pages.isEmpty {
            TabView(selection: $selectedPageIndex) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    LocationWeatherPageView(
                        page: page,
                        store: store,
                        isWide: isWide,
                        onOpenSunShadowMap: {
                            showSunShadowMap = true
                        },
                        onScrollChange: { scrolling in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isVerticalScrolling = scrolling
                            }
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: selectedPageIndex) { _, newIndex in
                handlePageSelection(newIndex)
            }
        } else {
            ProgressView(String(localized: "Loading weather…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Top Floating Bar (Recreated from scratch)

    private var topFloatingBar: some View {
        HStack(alignment: .center) {
            Button {
                showAddLocation = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .liquidGlassCircle(materialOpacity: 0.85)
            }
            .accessibilityLabel(String(localized: "Add location"))

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .liquidGlassCircle(materialOpacity: 0.85)
            }
            .accessibilityLabel(String(localized: "Settings"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .safeAreaPadding(.top)
        .zIndex(10)
    }

    // MARK: - Bottom Floating Dock

    private var bottomFloatingDock: some View {
        HStack(alignment: .center) {
            Button {
                showSunShadowMap = true
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .liquidGlassCircle(materialOpacity: 0.85)
            }
            .accessibilityLabel(String(localized: "Mappa Luce e Ombra"))

            Spacer()

            if pages.count > 1 {
                LocationLiquidGlassPagerPill(
                    pages: pages,
                    selectedIndex: selectedPageIndex,
                    isScrolling: isVerticalScrolling,
                    onSelectIndex: { targetIndex in
                        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) {
                            selectedPageIndex = targetIndex
                        }
                    }
                )
            }

            Spacer()

            // Balance spacer matching the left button width to keep the pager pill centered
            Color.clear
                .frame(width: 44, height: 44)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .zIndex(10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private func syncPageIndexFromStore() {
        let storeIndex = store.selectedPageIndex
        if selectedPageIndex != storeIndex && storeIndex < pages.count {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
                selectedPageIndex = storeIndex
            }
        }
    }

    private func handlePageSelection(_ newIndex: Int) {
        guard newIndex >= 0 && newIndex < pages.count else { return }
        let page = pages[newIndex]
        store.selectPageIndex(newIndex)
        Task {
            if page.isGPS && store.automaticLatitude == nil {
                if let coordinate = await locationManager.requestLocation(forceFresh: true) {
                    store.setAutomaticCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
            await store.fetchWeather(for: page)
        }
    }

    private func initialLoad() async {
        if store.isAutomaticGPSActive && store.automaticLatitude == nil {
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

// MARK: - Location Weather Page View (Full vertical weather dashboard for one location)

private struct LocationWeatherPageView: View {
    let page: WeatherStore.WeatherPageItem
    @Bindable var store: WeatherStore
    let isWide: Bool
    var onOpenSunShadowMap: () -> Void
    var onScrollChange: (Bool) -> Void

    private var weather: WeatherResponse? {
        store.weather(for: page.id)
    }

    private var isLoading: Bool {
        store.isPageLoading(for: page.id)
    }

    private var errorMessage: String? {
        store.errorMessage(for: page.id)
    }

    var body: some View {
        Group {
            if let weather {
                ScrollView(showsIndicators: false) {
                    Group {
                        if isWide {
                            wideLayout(weather: weather)
                        } else {
                            narrowLayout(weather: weather)
                        }
                    }
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 54)
                    .padding(.bottom, 90)
                }
                .refreshable {
                    await store.fetchWeather(for: page, force: true)
                }
            } else if let errorMessage {
                ContentUnavailableView {
                    Label(String(localized: "Couldn't load weather"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button(String(localized: "Retry")) {
                        Task { await store.fetchWeather(for: page, force: true) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text(String(localized: "Loading weather…"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 80)
            }
        }
        .task {
            if weather == nil {
                await store.fetchWeather(for: page)
            }
        }
    }

    // MARK: - Narrow Layout (iPhone)

    @ViewBuilder
    private func narrowLayout(weather: WeatherResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            heroHeaderView(weather: weather)

            let activeAlerts = store.alerts(for: weather)
            if !activeAlerts.isEmpty {
                WeatherAlertCardView(alerts: activeAlerts)
            }

            if let message = errorMessage {
                ErrorBannerView(message: message)
            }

            // 1. 3-Day Forecast
            EntranceCardView(index: 1) {
                ForecastListView(
                    items: store.dayItems(for: weather),
                    currentTemp: store.currentTempValue(for: weather)
                )
            }

            // 2. Temperature Trend
            EntranceCardView(index: 2) {
                TemperatureChartView(
                    points: store.chartPoints(for: weather),
                    midnights: store.chartMidnights(for: weather),
                    now: Date(),
                    unitSymbol: store.temperatureUnitSymbol,
                    observedTemp: store.currentTempValue(for: weather),
                    accent: store.theme(for: weather).accent
                )
            }

            // 3. Precipitation Chance
            EntranceCardView(index: 3) {
                PrecipitationChartView(
                    points: store.chartPoints(for: weather),
                    midnights: store.chartMidnights(for: weather),
                    accent: store.theme(for: weather).accent
                )
            }

            // 4. Hourly Forecast Strip
            EntranceCardView(index: 4) {
                HourlyStripView(items: store.upcomingHours(for: weather))
            }

            // 5. Sun & Shadow Spatial Intelligence Card
            EntranceCardView(index: 5) {
                SunShadowCardView(
                    state: store.solarState(for: page),
                    onOpenMap: onOpenSunShadowMap
                )
            }

            // 6. Lunar Phases Card
            EntranceCardView(index: 6) {
                MoonPhaseView(items: store.moonItems(for: weather))
            }

            // 7. Modular 2x2 Detail Tiles Grid
            EntranceStaggerView(index: 7) {
                DetailGridView(items: store.detailItems(for: weather))
            }
        }
    }

    // MARK: - Wide Layout (iPad)

    @ViewBuilder
    private func wideLayout(weather: WeatherResponse) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                heroHeaderView(weather: weather)

                let activeAlerts = store.alerts(for: weather)
                if !activeAlerts.isEmpty {
                    WeatherAlertCardView(alerts: activeAlerts)
                }

                if let message = errorMessage {
                    ErrorBannerView(message: message)
                }

                EntranceCardView(index: 1) {
                    ForecastListView(
                        items: store.dayItems(for: weather),
                        currentTemp: store.currentTempValue(for: weather)
                    )
                }

                EntranceCardView(index: 2) {
                    TemperatureChartView(
                        points: store.chartPoints(for: weather),
                        midnights: store.chartMidnights(for: weather),
                        now: Date(),
                        unitSymbol: store.temperatureUnitSymbol,
                        observedTemp: store.currentTempValue(for: weather),
                        accent: store.theme(for: weather).accent
                    )
                }

                EntranceCardView(index: 3) {
                    PrecipitationChartView(
                        points: store.chartPoints(for: weather),
                        midnights: store.chartMidnights(for: weather),
                        accent: store.theme(for: weather).accent
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                EntranceCardView(index: 4) {
                    HourlyStripView(items: store.upcomingHours(for: weather))
                }

                // Sun & Shadow Card (Wide Layout)
                EntranceCardView(index: 5) {
                    SunShadowCardView(
                        state: store.solarState(for: page),
                        onOpenMap: onOpenSunShadowMap
                    )
                }

                EntranceCardView(index: 6) {
                    MoonPhaseView(items: store.moonItems(for: weather))
                }

                EntranceStaggerView(index: 7) {
                    DetailGridView(items: store.detailItems(for: weather))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Hero Header View

    private func heroHeaderView(weather: WeatherResponse) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                if page.isGPS {
                    Image(systemName: "location.fill")
                        .font(.subheadline.weight(.semibold))
                }
                Text(store.locationName(for: page, weather: weather))
                    .font(.system(size: 34, weight: .regular))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)

            Text(store.currentTempText(for: weather))
                .font(.system(size: 88, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)

            Text(store.currentConditionText(for: weather))
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            if let today = weather.weather?.first {
                let maxT = store.useMetric ? (today.maxtempC ?? "-") + "°" : (today.maxtempF ?? "-") + "°"
                let minT = store.useMetric ? (today.mintempC ?? "-") + "°" : (today.mintempF ?? "-") + "°"
                Text("MAX: \(maxT)  MIN: \(minT)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 2)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

// MARK: - Reusable Section Card Container
private struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 18, materialOpacity: 0.85)
    }
}

// MARK: - Entrance Card View (Staggered Spring Animation)
private struct EntranceCardView<Content: View>: View {
    let index: Int
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        SectionCard { content }
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .scaleEffect(visible ? 1 : 0.98)
            .onAppear {
                guard !reduceMotion else {
                    visible = true
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.05)) {
                    visible = true
                }
            }
    }
}

// MARK: - Entrance Stagger View (For uncarded modular grids like DetailGridView)
private struct EntranceStaggerView<Content: View>: View {
    let index: Int
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .scaleEffect(visible ? 1 : 0.98)
            .onAppear {
                guard !reduceMotion else {
                    visible = true
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.05)) {
                    visible = true
                }
            }
    }
}
