import SwiftUI

// MARK: - Weather Animation Showcase View (Interactive Demo & Validation Suite)

/// Fullscreen interactive showcase to preview, inspect, and validate all photorealistic weather animations.
struct WeatherAnimationShowcaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    @State private var selectedIndex: Int
    @State private var showInfoCard: Bool = true
    @State private var simulateReduceMotion: Bool = false
    @State private var celestialMode: CelestialRenderMode = .composite
    @State private var celestialAtmosphereMode: CelestialAtmosphereDebugMode = .composite

    init(initialIndex: Int = 1) {
        var startIdx = initialIndex
        if let argIdx = ProcessInfo.processInfo.arguments.firstIndex(of: "-demoScene"),
           argIdx + 1 < ProcessInfo.processInfo.arguments.count,
           let parsed = Int(ProcessInfo.processInfo.arguments[argIdx + 1]) {
            startIdx = parsed
        }
        _selectedIndex = State(initialValue: startIdx)

        var mode: CelestialRenderMode = .composite
        if let modeIdx = ProcessInfo.processInfo.arguments.firstIndex(of: "-celestialMode"),
           modeIdx + 1 < ProcessInfo.processInfo.arguments.count,
           let parsedMode = Int32(ProcessInfo.processInfo.arguments[modeIdx + 1]),
           let customMode = CelestialRenderMode(rawValue: parsedMode) {
            mode = customMode
        }
        _celestialMode = State(initialValue: mode)

        var atmoMode: CelestialAtmosphereDebugMode = .composite
        if let atmoIdx = ProcessInfo.processInfo.arguments.firstIndex(of: "-celestialAtmosphereMode"),
           atmoIdx + 1 < ProcessInfo.processInfo.arguments.count,
           let parsedAtmo = Int32(ProcessInfo.processInfo.arguments[atmoIdx + 1]),
           let customAtmo = CelestialAtmosphereDebugMode(rawValue: parsedAtmo) {
            atmoMode = customAtmo
        }
        _celestialAtmosphereMode = State(initialValue: atmoMode)
    }

    private var items: [ShowcaseScene] {
        ShowcaseScene.allScenes
    }

    private var currentScene: ShowcaseScene {
        items[min(max(0, selectedIndex), items.count - 1)]
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Fullscreen Photorealistic Atmospheric Sky
            AnimatedWeatherBackgroundView(
                gradient: currentScene.theme.heroGradient,
                isNight: currentScene.isNight,
                showsStars: currentScene.showsStars,
                weatherKind: currentScene.kind,
                reduceMotionOverride: simulateReduceMotion ? true : nil,
                celestialRenderMode: celestialMode,
                celestialDebugMode: celestialAtmosphereMode,
                date: Date(),
                latitude: currentScene.latitude
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: selectedIndex)

            // 2. Main Content Overlay
            VStack(spacing: 0) {
                topNavigationBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        heroWeatherCard

                        if showInfoCard {
                            sceneDetailsCard
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 140) // Space for bottom dock
                }
            }

            // 3. Floating Bottom Carousel Selector
            VStack {
                Spacer()
                bottomCarouselPicker
            }
        }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Navigation Bar

    private var topNavigationBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Demo Animazioni"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(selectedIndex + 1)/\(items.count) • \(currentScene.title)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .liquidGlassCapsule(materialOpacity: 0.85)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showInfoCard.toggle()
                }
            } label: {
                Image(systemName: showInfoCard ? "info.circle.fill" : "info.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .liquidGlassCircle(materialOpacity: 0.85)
            }
            .accessibilityLabel(String(localized: "Dettagli animazione"))

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .liquidGlassCircle(materialOpacity: 0.85)
            }
            .accessibilityLabel(String(localized: "Close"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .safeAreaPadding(.top)
        .zIndex(10)
    }

    // MARK: - Hero Weather Card

    private var heroWeatherCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: currentScene.locationIcon)
                    .font(.subheadline.weight(.semibold))
                Text(currentScene.cityName)
                    .font(.system(size: 32, weight: .regular))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)

            AnimatedWeatherIconView(
                symbol: currentScene.symbol,
                kind: currentScene.kind,
                accessibilityLabel: currentScene.conditionTitle,
                foregroundColor: .white
            )
            .padding(.vertical, 4)

            Text(currentScene.temperature)
                .font(.system(size: 84, weight: .thin, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)

            Text(currentScene.conditionTitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            Text(currentScene.maxMin)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // MARK: - Scene Details Card

    private var sceneDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(currentScene.theme.accent)

                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Caratteristiche Realismo"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(String(localized: "Algoritmi procedurali in tempo reale"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                // Accessibility Reduce Motion Simulation Toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        simulateReduceMotion.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: simulateReduceMotion ? "pause.circle.fill" : "play.circle")
                        Text(simulateReduceMotion ? "Motion OFF" : "Motion ON")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(simulateReduceMotion ? Color.orange.opacity(0.8) : Color.white.opacity(0.2))
                    .clipShape(Capsule())
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(currentScene.features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(currentScene.theme.accent)
                            .padding(.top, 2)
                        Text(feature)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 8) {
                Text("CELESTIAL ATMOSPHERE (SOLE & LUNA DEBUG)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CelestialAtmosphereDebugMode.allCases) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    celestialAtmosphereMode = mode
                                }
                            } label: {
                                Text(mode.title)
                                    .font(.system(size: 11, weight: celestialAtmosphereMode == mode ? .bold : .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background {
                                        if celestialAtmosphereMode == mode {
                                            Capsule()
                                                .fill(Color.white.opacity(0.35))
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                                                )
                                        } else {
                                            Capsule()
                                                .fill(Color.black.opacity(0.25))
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                                                )
                                        }
                                    }
                            }
                        }
                    }
                }
            }

            if currentScene.isNight || currentScene.showsStars {
                Divider()
                    .background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 8) {
                    Text("MODALITÀ CIELO NOTTURNO (DEBUG STELLE)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))

                    HStack(spacing: 6) {
                        ForEach(CelestialRenderMode.allCases) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    celestialMode = mode
                                }
                            } label: {
                                Text(mode.title)
                                    .font(.system(size: 11, weight: celestialMode == mode ? .bold : .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background {
                                        if celestialMode == mode {
                                            Capsule()
                                                .fill(Color.white.opacity(0.35))
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                                                )
                                        } else {
                                            Capsule()
                                                .fill(Color.black.opacity(0.25))
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                                                )
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassCard(cornerRadius: 20, materialOpacity: 0.88)
    }

    // MARK: - Floating Bottom Carousel Selector

    private var bottomCarouselPicker: some View {
        VStack(spacing: 10) {
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, scene in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    selectedIndex = index
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: scene.symbol)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(scene.title)
                                        .font(.system(size: 13, weight: selectedIndex == index ? .bold : .medium))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background {
                                    if selectedIndex == index {
                                        Capsule()
                                            .fill(Color.white.opacity(0.35))
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.2)
                                            )
                                    } else {
                                        Capsule()
                                            .fill(Color.black.opacity(0.25))
                                            .overlay(
                                                Capsule()
                                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
                                            )
                                    }
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    withAnimation {
                        scrollProxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.25),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .zIndex(10)
    }
}

// MARK: - Showcase Scene Definition

struct ShowcaseScene: Identifiable {
    let id: String
    let title: String
    let cityName: String
    let locationIcon: String
    let temperature: String
    let conditionTitle: String
    let maxMin: String
    let symbol: String
    let kind: WeatherAnimationKind
    let isNight: Bool
    let showsStars: Bool
    let theme: WeatherTheme
    let features: [String]
    var latitude: Double = 45.0

    static let allScenes: [ShowcaseScene] = [
        ShowcaseScene(
            id: "sunny",
            title: "Soleggiato",
            cityName: "Roma",
            locationIcon: "location.fill",
            temperature: "32°",
            conditionTitle: "Soleggiato",
            maxMin: "MAX: 34°  MIN: 22°",
            symbol: "sun.max.fill",
            kind: .sun,
            isNight: false,
            showsStars: false,
            theme: .sunny,
            features: [
                "Disco solare fisico HDR con Solar Limb Darkening",
                "Corona ottica ad alta intensità e Mie Forward Scattering atmosferico",
                "Trasmissione ed estinzione di Rayleigh basata su airmass ed elevazione solare"
            ]
        ),
        ShowcaseScene(
            id: "partly_cloudy_day",
            title: "Parz. Nuvoloso (Giorno)",
            cityName: "Palazzo San Gervasio",
            locationIcon: "location.fill",
            temperature: "30°",
            conditionTitle: "Parzialmente nuvoloso",
            maxMin: "MAX: 30°  MIN: 21°",
            symbol: "cloud.sun.fill",
            kind: .partlyCloudy,
            isNight: false,
            showsStars: false,
            theme: .partlyCloudy,
            features: [
                "Volumetric Ray Marching 3D in Metal a 60 fps",
                "Density field procedurale multi-scala (FBM + Worley detail noise)",
                "Illuminazione volumetrica con Henyey-Greenstein, self-shadowing e silver lining",
                "Advezione del vento e domain warping per lenta evoluzione organica"
            ]
        ),
        ShowcaseScene(
            id: "partly_cloudy_night",
            title: "Parz. Nuvoloso (Notte)",
            cityName: "Tokyo",
            locationIcon: "building.2.fill",
            temperature: "22°",
            conditionTitle: "Parzialmente nuvoloso",
            maxMin: "MAX: 24°  MIN: 19°",
            symbol: "cloud.moon.fill",
            kind: .partlyCloudy,
            isNight: true,
            showsStars: true,
            theme: .partlyCloudyNight,
            features: [
                "Catalogo stellare astronomico a sorgenti puntiformi sub-pixel stabili (PSF)",
                "Via Lattea macro-scale ad alta morbidezza con corsie oscure (Dark Dust Lanes)",
                "Nubi volumetriche 3D con illuminazione lunare argentata",
                "Attenuazione atmosferica e lunare con scintillio deterministico"
            ]
        ),
        ShowcaseScene(
            id: "cloudy",
            title: "Nuvoloso / Coperto",
            cityName: "Dublino",
            locationIcon: "location.fill",
            temperature: "18°",
            conditionTitle: "Nuvoloso",
            maxMin: "MAX: 20°  MIN: 15°",
            symbol: "cloud.fill",
            kind: .cloud,
            isNight: false,
            showsStars: false,
            theme: .cloudy,
            features: [
                "Manto stratocumuliforme continuo con Ray Marching 3D in Metal",
                "Altezza profilo con base irregolare e densità volumetrica omogenea",
                "Diffusione solare atmosferica superiore senza gradienti artificiali",
                "Evoluzione temporale fluida e continua senza pulsazioni"
            ]
        ),
        ShowcaseScene(
            id: "rain",
            title: "Pioggia",
            cityName: "Londra",
            locationIcon: "building.2.fill",
            temperature: "16°",
            conditionTitle: "Pioggia",
            maxMin: "MAX: 17°  MIN: 12°",
            symbol: "cloud.rain.fill",
            kind: .rain,
            isNight: false,
            showsStars: false,
            theme: .rainy,
            features: [
                "Copertura nubi piovose volumetriche con Ray Marching 3D Metal",
                "4 livelli di profondità: pioggerellina fine veloce di sfondo",
                "Gocce medie con inclinazione al vento e sfocatura cinetica",
                "Gocce rifrattive pesanti in primo piano e nebbia di evaporazione al suolo"
            ]
        ),
        ShowcaseScene(
            id: "storm",
            title: "Temporale",
            cityName: "Milano",
            locationIcon: "building.2.fill",
            temperature: "21°",
            conditionTitle: "Temporale",
            maxMin: "MAX: 23°  MIN: 18°",
            symbol: "cloud.bolt.rain.fill",
            kind: .storm,
            isNight: false,
            showsStars: false,
            theme: .stormy,
            features: [
                "Cumulonembi temporaleschi 3D in Metal ad alta densità volumetrica",
                "Saette ramificate procedurali generate dinamicamente",
                "Lampi atmosferici a triplo impulso con illuminazione della massa nuvolosa"
            ]
        ),
        ShowcaseScene(
            id: "snow",
            title: "Neve",
            cityName: "St. Moritz",
            locationIcon: "building.2.fill",
            temperature: "-2°",
            conditionTitle: "Neve",
            maxMin: "MAX: 0°  MIN: -5°",
            symbol: "snowflake",
            kind: .snow,
            isNight: false,
            showsStars: false,
            theme: .snowy,
            features: [
                "Manto nuvoloso nevoso volumetrico 3D in Metal",
                "Fiocchi di neve con oscillazione sinusoidale e flutter organico",
                "3 piani di parallasse: micro-cristalli veloci, fiocchi medi e macro-sfocati"
            ]
        ),
        ShowcaseScene(
            id: "fog",
            title: "Nebbia / Foschia",
            cityName: "San Francisco",
            locationIcon: "building.2.fill",
            temperature: "14°",
            conditionTitle: "Nebbia",
            maxMin: "MAX: 16°  MIN: 11°",
            symbol: "cloud.fog.fill",
            kind: .fog,
            isNight: false,
            showsStars: false,
            theme: .foggy,
            features: [
                "Volume atmosferico continuo in Metal fullscreen (zero bande geometriche)",
                "Height fog con densità verticale, scattering Mie ed estinzione di Beer-Lambert",
                "Noise procedurale a bassissima frequenza con domain warping e lenta advezione",
                "Differenziazione tra nebbia e foschia tramite densità e trasparenza"
            ]
        ),
        ShowcaseScene(
            id: "clear_night",
            title: "Notte Serena",
            cityName: "Parigi",
            locationIcon: "location.fill",
            temperature: "19°",
            conditionTitle: "Sereno",
            maxMin: "MAX: 22°  MIN: 16°",
            symbol: "moon.stars.fill",
            kind: .moon,
            isNight: true,
            showsStars: true,
            theme: .clearNight,
            features: [
                "Luna 3D sferica con ciclo lunare astronomico reale in base a data e località",
                "Emisfero non illuminato completamente scuro senza silhouette né aloni spuri",
                "Albedo procedurale della superficie: Maria basaltici, Highlands e crateri da impatto",
                "Catalogo stellare astronomico a sorgenti puntiformi sub-pixel stabili (PSF)"
            ],
            latitude: 48.8566
        )
    ]
}
