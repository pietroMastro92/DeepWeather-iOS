import SwiftUI
import MapKit
import CoreLocation

// MARK: - Sun & Shadow Map View (100% Native Building & Terrain Shadow Engine)

/// Independent native spatial engine that calculates and renders real building shadow polygons
/// and solar illumination on a clean vector map, inspired by ShadeMap principles without web embedding.
struct SunShadowMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var store: WeatherStore
    let page: WeatherStore.WeatherPageItem

    // MARK: - State

    @State private var cameraPosition: MapCameraPosition
    @State private var mapStyleSelection: MapStyleOption = .darkVector
    @State private var navigationIntent: SolarShadowEngine.NavigationIntent = .seekShade

    // Buildings & Computed Shadow Mesh
    @State private var buildings: [BuildingFootprint] = []
    @State private var isLoadingBuildings: Bool = true

    // Time Scrubber (Minutes from midnight 0...1439)
    @State private var simulatedMinutes: Double
    @State private var isSimulatingCustomTime: Bool = false
    @State private var isPlayingAnimation: Bool = false
    @State private var timerTask: Task<Void, Never>? = nil

    // MARK: - Enums

    enum MapStyleOption: String, CaseIterable, Identifiable {
        case standardVector = "standard_vector"
        case darkVector = "dark_vector"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .standardVector: return String(localized: "Vettoriale Chiara")
            case .darkVector: return String(localized: "Vettoriale Scura")
            }
        }

        var icon: String {
            switch self {
            case .standardVector: return "map"
            case .darkVector: return "moon.fill"
            }
        }
    }

    // MARK: - Initializer

    init(store: WeatherStore, page: WeatherStore.WeatherPageItem) {
        self.store = store
        self.page = page

        let coord = store.coordinate(for: page)
        let initialCamera = MapCameraPosition.camera(
            MapCamera(
                centerCoordinate: coord,
                distance: 400,
                heading: 0,
                pitch: 0
            )
        )
        _cameraPosition = State(initialValue: initialCamera)

        // Initialize scrubber to current local time minutes
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let min = cal.component(.minute, from: now)
        _simulatedMinutes = State(initialValue: Double(hour * 60 + min))
    }

    // MARK: - Computed Properties

    private var targetCoordinate: CLLocationCoordinate2D {
        store.coordinate(for: page)
    }

    private var targetDate: Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        return startOfDay.addingTimeInterval(simulatedMinutes * 60.0)
    }

    private var solarState: SolarShadowEngine.State {
        store.solarState(for: page, date: targetDate)
    }

    private var projectedShadows: [ProjectedShadowPolygon] {
        BuildingShadowGeometry.computeShadows(
            for: buildings,
            solarPosition: solarState.solarPosition
        )
    }

    private var formattedSimulatedTime: String {
        let total = Int(simulatedMinutes)
        let h = (total / 60) % 24
        let m = total % 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Native MapKit Map with Projected Shadow Polygons & Building Footprints
            nativeMapKitView
                .ignoresSafeArea()

            // Top Floating Header & Guidance Pill
            VStack(spacing: 8) {
                topHeaderBar
                guidanceBanner
            }
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 14)
            .safeAreaPadding(.top)

            // Bottom Control Deck: Scrubber + Milestones + Metrics
            VStack(spacing: 8) {
                Spacer()
                bottomControlDeck
            }
            .environment(\.colorScheme, .dark)
            .padding(.horizontal, 14)
            .safeAreaPadding(.bottom)
        }
        .preferredColorScheme(mapStyleSelection == .darkVector ? .dark : nil)
        .task {
            await loadBuildingFootprints()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    // MARK: - Native MapKit View

    private var nativeMapKitView: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            // 1. Render Projected Building Shadow Polygons (ShadeMap Slate Tone)
            ForEach(projectedShadows) { shadow in
                MapPolygon(coordinates: shadow.coordinates)
                    .foregroundStyle(
                        Color(red: 0.42, green: 0.48, blue: 0.58)
                            .opacity(solarState.shadowQuality.opacity * 0.72)
                    )
            }

            // 2. Render Building Footprints on Top of Ground Shadows
            ForEach(buildings) { building in
                MapPolygon(coordinates: building.coordinates)
                    .foregroundStyle(Color(red: 0.60, green: 0.62, blue: 0.64))
                    .stroke(Color(red: 0.32, green: 0.35, blue: 0.38), lineWidth: 1.0)
            }

            // 3. User Location Marker
            Annotation(page.name, coordinate: targetCoordinate) {
                UserLocationIndicatorView(
                    solarState: solarState,
                    intent: navigationIntent
                )
            }

            // 4. Distant Horizon Sun Ray Indicator
            if solarState.solarPosition.isDaylight {
                let sunCoord = coordinateOffset(
                    from: targetCoordinate,
                    distanceMeters: 220,
                    bearingDegrees: solarState.solarPosition.azimuth
                )
                Annotation("Sole", coordinate: sunCoord) {
                    SunOrbIndicatorView(
                        elevation: solarState.solarPosition.elevation,
                        azimuth: solarState.solarPosition.azimuth
                    )
                }
            }
        }
        .mapStyle(
            .standard(
                elevation: .flat,
                emphasis: .muted,
                pointsOfInterest: .including([.park, .publicTransport, .school, .restaurant])
            )
        )
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        HStack(spacing: 8) {
            // Location Info Pill
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if page.isGPS {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.cyan)
                    }
                    Text(page.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text(formattedSimulatedTime)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.yellow)

                    if isSimulatingCustomTime {
                        Text(String(localized: "(Simulazione)"))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.75))
                    } else {
                        Text(String(localized: "(Ora locale)"))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .liquidGlassCapsule(materialOpacity: 0.88)

            Spacer()

            // Map Style Switcher Menu
            Menu {
                Picker(String(localized: "Stile Mappa"), selection: $mapStyleSelection) {
                    ForEach(MapStyleOption.allCases) { option in
                        Label(option.title, systemImage: option.icon).tag(option)
                    }
                }

                Button {
                    centerOnLocation()
                } label: {
                    Label(String(localized: "Centra Posizione"), systemImage: "location.fill")
                }
            } label: {
                Image(systemName: "square.2.layers.3d")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .liquidGlassCircle(materialOpacity: 0.88)
            }

            // Close Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .liquidGlassCircle(materialOpacity: 0.88)
            }
            .accessibilityLabel(String(localized: "Chiudi mappa"))
        }
    }

    // MARK: - Guidance Banner

    private var guidanceBanner: some View {
        VStack(spacing: 6) {
            // Intent Switcher Capsule ("Trova Ombra" vs "Cerca Sole")
            HStack(spacing: 4) {
                ForEach(SolarShadowEngine.NavigationIntent.allCases) { intent in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            navigationIntent = intent
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: intent.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(intent.title)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background {
                            if navigationIntent == intent {
                                Capsule()
                                    .fill(intent == .seekShade ? Color.teal.opacity(0.85) : Color.orange.opacity(0.85))
                                    .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
                            }
                        }
                        .foregroundStyle(navigationIntent == intent ? .white : .white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.8))

            // Guidance Text
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: navigationIntent == .seekShade ? "shield.fill" : "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(navigationIntent == .seekShade ? .cyan : .yellow)
                    .padding(.top, 1)

                Text(solarState.guidance(for: navigationIntent))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlassCard(cornerRadius: 12, materialOpacity: 0.88)
        }
    }

    // MARK: - Bottom Control Deck

    private var bottomControlDeck: some View {
        VStack(spacing: 8) {
            // Timeline Scrubber & Quick Milestones
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Button {
                        togglePlayAnimation()
                    } label: {
                        Image(systemName: isPlayingAnimation ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.yellow)
                            .frame(width: 30, height: 30)
                            .background(.ultraThinMaterial, in: Circle())
                    }

                    Slider(
                        value: $simulatedMinutes,
                        in: 0...1439,
                        step: 5
                    ) {
                        Text(String(localized: "Orario"))
                    } minimumValueLabel: {
                        Text("00:00")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    } maximumValueLabel: {
                        Text("23:59")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .tint(.yellow)
                    .onChange(of: simulatedMinutes) { _, _ in
                        isSimulatingCustomTime = true
                    }

                    Button {
                        resetToCurrentTime()
                    } label: {
                        Text(String(localized: "Ora"))
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                // Solar Milestone Quick Jump Buttons
                HStack(spacing: 5) {
                    if let sunrise = solarState.milestones.sunrise {
                        milestonePill(title: String(localized: "Alba"), date: sunrise, icon: "sunrise.fill")
                    }
                    if let noon = solarState.milestones.solarNoon {
                        milestonePill(title: String(localized: "Mezzogiorno"), date: noon, icon: "sun.max.fill")
                    }
                    if let golden = solarState.milestones.goldenHourEveningStart {
                        milestonePill(title: String(localized: "Golden Hour"), date: golden, icon: "sun.haze.fill")
                    }
                    if let sunset = solarState.milestones.sunset {
                        milestonePill(title: String(localized: "Tramonto"), date: sunset, icon: "sunset.fill")
                    }
                }
            }
            .padding(10)
            .liquidGlassCard(cornerRadius: 14, materialOpacity: 0.88)

            // Metrics Summary
            HStack(spacing: 6) {
                MetricPill(
                    title: String(localized: "Elevazione"),
                    value: String(format: "%.1f°", solarState.solarPosition.elevation),
                    symbol: "sun.max.fill",
                    color: .yellow
                )
                MetricPill(
                    title: String(localized: "Azimut"),
                    value: "\(Int(solarState.solarPosition.azimuth))° \(SolarShadowEngine.shortCompass(for: solarState.solarPosition.azimuth))",
                    symbol: "safari.fill",
                    color: .orange
                )
                MetricPill(
                    title: String(localized: "Edifici"),
                    value: "\(buildings.count)",
                    symbol: "building.2.fill",
                    color: .indigo
                )
                MetricPill(
                    title: String(localized: "UV / Nubi"),
                    value: "\(solarState.uvIndex) / \(solarState.cloudCoverPercent)%",
                    symbol: "cloud.sun.fill",
                    color: .cyan
                )
            }
        }
    }

    // MARK: - Milestone Pill Helper

    private func milestonePill(title: String, date: Date, icon: String) -> some View {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let mins = Double(h * 60 + m)

        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                simulatedMinutes = mins
                isSimulatingCustomTime = true
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.6))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Building Footprints Loading

    private func loadBuildingFootprints() async {
        isLoadingBuildings = true
        let fetched = await BuildingShadowService.shared.fetchBuildings(around: targetCoordinate, radiusMeters: 650)
        withAnimation(.easeOut(duration: 0.3)) {
            self.buildings = fetched
            self.isLoadingBuildings = false
        }
    }

    // MARK: - Actions & Animation

    private func togglePlayAnimation() {
        if isPlayingAnimation {
            stopAnimation()
        } else {
            startAnimation()
        }
    }

    private func startAnimation() {
        isPlayingAnimation = true
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled && isPlayingAnimation {
                try? await Task.sleep(nanoseconds: 120_000_000)
                await MainActor.run {
                    simulatedMinutes = (simulatedMinutes + 10).truncatingRemainder(dividingBy: 1440)
                }
            }
        }
    }

    private func stopAnimation() {
        isPlayingAnimation = false
        timerTask?.cancel()
        timerTask = nil
    }

    private func resetToCurrentTime() {
        stopAnimation()
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let min = cal.component(.minute, from: now)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            simulatedMinutes = Double(hour * 60 + min)
            isSimulatingCustomTime = false
        }
    }

    private func centerOnLocation() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            cameraPosition = MapCameraPosition.camera(
                MapCamera(
                    centerCoordinate: targetCoordinate,
                    distance: 400,
                    heading: 0,
                    pitch: 0
                )
            )
        }
    }

    private func coordinateOffset(
        from origin: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6378137.0
        let dByR = distanceMeters / earthRadius
        let latRad = origin.latitude * .pi / 180.0
        let lonRad = origin.longitude * .pi / 180.0
        let bearingRad = bearingDegrees * .pi / 180.0

        let lat2 = asin(sin(latRad) * cos(dByR) + cos(latRad) * sin(dByR) * cos(bearingRad))
        let lon2 = lonRad + atan2(sin(bearingRad) * sin(dByR) * cos(latRad), cos(dByR) - sin(latRad) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }
}

// MARK: - User Location Indicator View

private struct UserLocationIndicatorView: View {
    let solarState: SolarShadowEngine.State
    let intent: SolarShadowEngine.NavigationIntent

    var body: some View {
        ZStack {
            // Outer Pulsing Glow
            Circle()
                .fill((intent == .seekShade ? Color.teal : Color.orange).opacity(0.25))
                .frame(width: 32, height: 32)

            // Inner Marker
            Circle()
                .fill(intent == .seekShade ? Color.teal : Color.orange)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.35), radius: 3)

            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Sun Orb Indicator View

private struct SunOrbIndicatorView: View {
    let elevation: Double
    let azimuth: Double

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(.yellow.opacity(0.3))
                    .frame(width: 32, height: 32)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.yellow, .orange],
                            center: .center,
                            startRadius: 2,
                            endRadius: 12
                        )
                    )
                    .frame(width: 20, height: 20)
                    .shadow(color: .yellow, radius: 6)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("\(Int(elevation))°")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Metric Pill

private struct MetricPill: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .liquidGlassCard(cornerRadius: 10, materialOpacity: 0.88)
    }
}
