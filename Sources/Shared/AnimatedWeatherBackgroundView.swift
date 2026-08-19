import SwiftUI

// MARK: - Animated Weather Background View

/// Photorealistic atmospheric animated background matching Apple Weather design standards:
/// - Sunny: Physically-based HDR Sun Disk with solar limb darkening, optical corona flare, and forward Mie atmospheric scattering.
/// - Partly Cloudy: Physical Sun (or 3D spherical Moon) with exact optical alignment + real-time 3D volumetric raymarched clouds.
/// - Cloudy / Overcast: Realistic continuous stratocumulus and stratus cloud deck with ambient sun filtration, soft textured undulating billows, and low-altitude scud mist.
/// - Rain: 3D multi-layered cinematic rainfall with wind-slanted motion blur streaks, distant drizzle curtains, foreground refractive heavy drops, and low-altitude splash mist.
/// - Storm: Heavy wind-driven rain, dark turbulent cumulonimbus cloud shelf, ambient lightning flashes, and branching lightning bolt discharges.
/// - Snow: Multi-plane 3D snowfall with organic sinusoidal sway, flutter, variable particle sizes, and foreground depth-of-field blur.
/// - Fog: Multi-layered rolling volumetric fog banks with soft gaussian opacity gradients and undulating ribbons.
/// - Moon / Clear Night: True 3D Spherical Moon with basaltic maria, highland crater albedo, geometric phase terminator, delicate earthshine, and concentric atmospheric glow.
/// Fully respects Reduce Motion for accessibility.
struct AnimatedWeatherBackgroundView: View {
    let gradient: [Color]
    let isNight: Bool
    var showsStars: Bool = false
    var weatherKind: WeatherAnimationKind = .cloud
    var reduceMotionOverride: Bool? = nil
    var celestialRenderMode: CelestialRenderMode = .composite
    var celestialDebugMode: CelestialAtmosphereDebugMode = .composite
    var limitingMagnitude: Float = 5.2
    var date: Date = Date()
    var latitude: Double = 45.0
    var moonToSunDir: (Float, Float, Float)? = nil
    var moonPhase: Float? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effectiveReduceMotion: Bool {
        reduceMotionOverride ?? reduceMotion
    }

    private var resolvedMoonToSunDir: (Float, Float, Float) {
        moonToSunDir ?? LunarPhaseEngine.moonToSunDirection(for: date, latitude: latitude)
    }

    private var resolvedMoonPhase: Float {
        moonPhase ?? Float(LunarPhaseEngine.phase(for: date))
    }

    @State private var lightningFlash: Double = 0
    @State private var lightningBoltAlpha: Double = 0
    @State private var lightningSeed: Int = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // Base Daylight/Night sky atmospheric gradient
                LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)

                if !effectiveReduceMotion {
                    switch weatherKind {
                    case .sun:
                        photorealisticSunSky(in: size)
                    case .partlyCloudy:
                        photorealisticPartlyCloudySky(in: size)
                    case .cloud:
                        photorealisticCloudSky(in: size)
                    case .moon:
                        photorealisticMoonSky(in: size)
                    case .fog:
                        photorealisticFogSky(in: size)
                    case .rain:
                        photorealisticRainSky(in: size)
                    case .snow:
                        photorealisticSnowSky(in: size)
                    case .storm:
                        photorealisticStormSky(in: size)
                    }

                    // Metal Celestial Night Sky (Astronomical Point Sources + Macro-Scale Milky Way)
                    if (showsStars || isNight) && weatherKind != .rain && weatherKind != .storm {
                        CelestialNightSkyView(
                            moonPos: (0.70, 0.20),
                            moonBrightness: 1.0,
                            milkyWayIntensity: (weatherKind == .cloud || weatherKind == .fog) ? 0.14 : 0.36,
                            starIntensity: (weatherKind == .cloud || weatherKind == .fog) ? 0.40 : 0.95,
                            limitingMagnitude: limitingMagnitude,
                            renderMode: celestialRenderMode
                        )
                        .frame(width: size.width, height: size.height)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    // MARK: - 1. Photorealistic Sunny Sky (Physically-Based Metal Sun Disk & Mie/Rayleigh Atmosphere)

    private func photorealisticSunSky(in size: CGSize) -> some View {
        CelestialAtmosphereView(
            isNight: false,
            debugMode: celestialDebugMode
        )
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - 2. Photorealistic Partly Cloudy Sky (Sun/Moon + Metal 3D Volumetric Raymarched Clouds)

    private func photorealisticPartlyCloudySky(in size: CGSize) -> some View {
        let aspect = Float(size.width / size.height)
        let sunRay = CelestialAtmosphereEngine.rayDirection(for: CGPoint(x: 0.32, y: 0.18), aspect: aspect)
        let moonRay = CelestialAtmosphereEngine.rayDirection(for: CGPoint(x: 0.70, y: 0.20), aspect: aspect)

        return ZStack {
            // 1. Physically-Based Celestial Body (Sun / Moon) in Metal
            CelestialAtmosphereView(
                isNight: isNight,
                sunDir: sunRay,
                moonDir: moonRay,
                moonToSunDir: resolvedMoonToSunDir,
                moonPhase: resolvedMoonPhase,
                debugMode: celestialDebugMode
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)

            // 2. Real-Time Procedural 3D Volumetric Raymarched Clouds in Metal (Ultra-Fast 60+ FPS)
            VolumetricCloudsView(
                coverage: 0.42,
                sunDir: isNight ? moonRay : sunRay,
                isNight: isNight,
                isOvercast: false,
                timeScale: 1.0
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }

    // MARK: - 3. Photorealistic Cloudy / Overcast Sky (Continuous Multi-Layer Stratocumulus Metal Raymarch)

    private func photorealisticCloudSky(in size: CGSize) -> some View {
        ZStack {
            // Atmospheric ambient light dome filtering through overcast canopy
            LinearGradient(
                colors: [
                    Color.white.opacity(isNight ? 0.08 : 0.35),
                    Color(red: 0.92, green: 0.95, blue: 0.98).opacity(isNight ? 0.04 : 0.18),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            // Real-Time Procedural 3D Volumetric Raymarched Overcast Canopy in Metal
            VolumetricCloudsView(
                coverage: 0.76,
                sunDir: (0.0, 0.95, 0.25),
                isNight: isNight,
                isOvercast: true,
                timeScale: 0.85
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }

    // MARK: - 4. Photorealistic Rain Sky (Metal Volumetric Cloud Deck + Multi-layered 3D Cinematic Precipitation)

    private func photorealisticRainSky(in size: CGSize) -> some View {
        ZStack {
            // 1. Metal Volumetric Overcast Rain Clouds Deck
            VolumetricCloudsView(
                coverage: 0.84,
                sunDir: (0.10, 0.90, 0.25),
                isNight: isNight,
                isOvercast: true,
                timeScale: 0.95
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)

            // 2. Multi-Layer Cinematic Precipitation
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, canvasSize in
                    let width = canvasSize.width
                    let height = canvasSize.height
                    let totalHeight = height + 140
                    let windSlantX = -4.5 // Natural wind angle tilt for raindrops

                    // LAYER 1: Distant Fine Drizzle Veil (130+ micro-streaks)
                    let bgCount = 130
                    for i in 0..<bgCount {
                        let seed = Double(i)
                        let speed = 560.0 + (seed.truncatingRemainder(dividingBy: 8)) * 45.0
                        let xBase = (seed * 0.073).truncatingRemainder(dividingBy: 1.0) * (width + 80) - 40
                        let yPos = (elapsed * speed + seed * 41.0).truncatingRemainder(dividingBy: totalHeight) - 60

                        let dropLength = 18.0 + (seed.truncatingRemainder(dividingBy: 4)) * 6.0
                        var path = Path()
                        path.move(to: CGPoint(x: xBase, y: yPos))
                        path.addLine(to: CGPoint(x: xBase + windSlantX * (dropLength / 18.0), y: yPos + dropLength))

                        let opacity = 0.20 + (seed.truncatingRemainder(dividingBy: 4)) * 0.08
                        context.stroke(
                            path,
                            with: .color(Color.white.opacity(opacity)),
                            lineWidth: 1.0
                        )
                    }

                    // LAYER 2: Midground Directional Raindrops (80 streaks with motion blur)
                    let midCount = 80
                    for i in 0..<midCount {
                        let seed = Double(i + 140)
                        let speed = 760.0 + (seed.truncatingRemainder(dividingBy: 7)) * 60.0
                        let xBase = (seed * 0.113).truncatingRemainder(dividingBy: 1.0) * (width + 100) - 50
                        let yPos = (elapsed * speed + seed * 59.0).truncatingRemainder(dividingBy: totalHeight) - 70

                        let dropLength = 28.0 + (seed.truncatingRemainder(dividingBy: 5)) * 10.0
                        let startPoint = CGPoint(x: xBase, y: yPos)
                        let endPoint = CGPoint(x: xBase + windSlantX * (dropLength / 20.0), y: yPos + dropLength)

                        var path = Path()
                        path.move(to: startPoint)
                        path.addLine(to: endPoint)

                        context.stroke(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [
                                    Color.white.opacity(0.08),
                                    Color(red: 0.88, green: 0.95, blue: 1.0).opacity(0.50)
                                ]),
                                startPoint: startPoint,
                                endPoint: endPoint
                            ),
                            lineWidth: 1.6
                        )
                    }

                    // LAYER 3: Foreground Refractive Heavy Drops (36 large drops)
                    let fgCount = 36
                    for i in 0..<fgCount {
                        let seed = Double(i + 280)
                        let speed = 980.0 + (seed.truncatingRemainder(dividingBy: 5)) * 80.0
                        let xBase = (seed * 0.163).truncatingRemainder(dividingBy: 1.0) * (width + 120) - 60
                        let yPos = (elapsed * speed + seed * 73.0).truncatingRemainder(dividingBy: totalHeight) - 80

                        let dropLength = 42.0 + (seed.truncatingRemainder(dividingBy: 4)) * 14.0
                        let startPoint = CGPoint(x: xBase, y: yPos)
                        let endPoint = CGPoint(x: xBase + windSlantX * (dropLength / 22.0), y: yPos + dropLength)

                        var path = Path()
                        path.move(to: startPoint)
                        path.addLine(to: endPoint)

                        context.stroke(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [
                                    Color.white.opacity(0.12),
                                    Color(red: 0.94, green: 0.98, blue: 1.0).opacity(0.75)
                                ]),
                                startPoint: startPoint,
                                endPoint: endPoint
                            ),
                            lineWidth: 2.4
                        )
                    }

                    // Ground Splash Mist & Rising Surface Vapor
                    let splashHazeRect = CGRect(x: 0, y: height * 0.80, width: width, height: height * 0.20)
                    var splashPath = Path()
                    splashPath.addRect(splashHazeRect)
                    context.fill(
                        splashPath,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.clear,
                                Color(red: 0.70, green: 0.80, blue: 0.92).opacity(0.14),
                                Color.white.opacity(0.24)
                            ]),
                            startPoint: CGPoint(x: width * 0.5, y: splashHazeRect.minY),
                            endPoint: CGPoint(x: width * 0.5, y: splashHazeRect.maxY)
                        )
                    )
                }
            }
        }
    }

    // MARK: - 5. Photorealistic Storm Sky (Metal Cumulonimbus Storm Clouds + Lightning & Heavy Rain)

    private func photorealisticStormSky(in size: CGSize) -> some View {
        ZStack {
            // 1. Metal Volumetric Cumulonimbus Storm Clouds Deck
            VolumetricCloudsView(
                coverage: 0.92,
                sunDir: (0.05, 0.95, 0.20),
                isNight: isNight,
                isOvercast: true,
                timeScale: 1.25
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)

            // 2. Cinematic Rain Precipitation
            photorealisticRainSky(in: size)

            // 3. Branching Lightning Bolt Discharges
            if lightningBoltAlpha > 0 {
                Canvas { context, canvasSize in
                    let w = canvasSize.width
                    let h = canvasSize.height
                    let startX = w * (0.25 + Double(lightningSeed % 5) * 0.12)
                    let startY = h * 0.05

                    var path = Path()
                    path.move(to: CGPoint(x: startX, y: startY))
                    var curr = CGPoint(x: startX, y: startY)

                    let segments = 7
                    for seg in 1...segments {
                        let segProgress = Double(seg) / Double(segments)
                        let targetY = startY + (h * 0.55) * segProgress
                        let jitterX = (Double((lightningSeed * 17 + seg * 31) % 40) - 20.0)
                        let nextPoint = CGPoint(x: curr.x + jitterX, y: targetY)
                        path.addLine(to: nextPoint)

                        if seg == 3 || seg == 5 {
                            var branchPath = Path()
                            branchPath.move(to: nextPoint)
                            let bTarget = CGPoint(x: nextPoint.x + (seg == 3 ? -35 : 40), y: nextPoint.y + 45)
                            branchPath.addLine(to: bTarget)
                            context.stroke(
                                branchPath,
                                with: .color(Color.white.opacity(lightningBoltAlpha * 0.65)),
                                lineWidth: 1.5
                            )
                        }

                        curr = nextPoint
                    }

                    context.stroke(
                        path,
                        with: .color(Color(red: 0.75, green: 0.85, blue: 1.0).opacity(lightningBoltAlpha * 0.5)),
                        lineWidth: 6.0
                    )
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(lightningBoltAlpha)),
                        lineWidth: 2.5
                    )
                }
            }

            // 4. Ambient Lightning Flash
            Color.white
                .opacity(lightningFlash)
                .ignoresSafeArea()
                .blendMode(.screen)
        }
        .task {
            await triggerLightningLoop()
        }
    }

    private func triggerLightningLoop() async {
        guard !effectiveReduceMotion else { return }
        while !Task.isCancelled {
            let randomDelay = Double.random(in: 4.5...9.5)
            try? await Task.sleep(for: .milliseconds(Int(randomDelay * 1000)))
            guard !Task.isCancelled, !effectiveReduceMotion else { break }

            lightningSeed = Int.random(in: 1...1000)

            // Step 1: Pre-discharge flicker
            withAnimation(.easeIn(duration: 0.05)) {
                lightningFlash = 0.35
                lightningBoltAlpha = 0.40
            }
            try? await Task.sleep(for: .milliseconds(60))

            withAnimation(.easeOut(duration: 0.06)) {
                lightningFlash = 0.0
                lightningBoltAlpha = 0.0
            }
            try? await Task.sleep(for: .milliseconds(50))

            // Step 2: Main high-intensity lightning strike
            withAnimation(.easeIn(duration: 0.06)) {
                lightningFlash = 0.85
                lightningBoltAlpha = 1.0
            }
            try? await Task.sleep(for: .milliseconds(90))

            // Step 3: Reverberation fade-out
            withAnimation(.easeOut(duration: 0.40)) {
                lightningFlash = 0.0
                lightningBoltAlpha = 0.0
            }
        }
    }

    // MARK: - 6. Photorealistic Snow Sky (Metal Winter Clouds + Volumetric Multi-Plane Snowflakes)

    private func photorealisticSnowSky(in size: CGSize) -> some View {
        ZStack {
            // 1. Metal Volumetric Winter Clouds Deck
            VolumetricCloudsView(
                coverage: 0.78,
                sunDir: (0.15, 0.88, 0.30),
                isNight: isNight,
                isOvercast: true,
                timeScale: 0.75
            )
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)

            // 2. Volumetric Multi-Plane Snowflakes
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, canvasSize in
                    let width = canvasSize.width
                    let height = canvasSize.height
                    let totalH = height + 60.0

                    // LAYER 1: Background Distant Snow Dust (40 micro flakes)
                    let bgCount = 40
                    for i in 0..<bgCount {
                        let seed = Double(i)
                        let speed = 32.0 + (seed.truncatingRemainder(dividingBy: 5)) * 14.0
                        let xBase = (seed * 0.137).truncatingRemainder(dividingBy: 1.0) * width
                        let xSway = sin(elapsed * 0.9 + seed * 1.8) * 12.0
                        let x = xBase + xSway
                        let y = (elapsed * speed + seed * 43.0).truncatingRemainder(dividingBy: Double(totalH)) - 20.0
                        let radius = 1.5 + (seed.truncatingRemainder(dividingBy: 3)) * 0.8

                        let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color.white.opacity(0.35 + (seed.truncatingRemainder(dividingBy: 3)) * 0.12))
                        )
                    }

                    // LAYER 2: Midground Tumbling Snowflakes (35 soft flakes)
                    let midCount = 35
                    for i in 0..<midCount {
                        let seed = Double(i + 80)
                        let speed = 48.0 + (seed.truncatingRemainder(dividingBy: 4)) * 18.0
                        let xBase = (seed * 0.173).truncatingRemainder(dividingBy: 1.0) * width
                        let xSway = sin(elapsed * 1.3 + seed * 1.4) * 22.0
                        let x = xBase + xSway
                        let y = (elapsed * speed + seed * 37.0).truncatingRemainder(dividingBy: Double(totalH)) - 25.0
                        let radius = 3.0 + (seed.truncatingRemainder(dividingBy: 3)) * 1.5

                        let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [
                                    Color.white.opacity(0.85),
                                    Color(red: 0.92, green: 0.96, blue: 1.0).opacity(0.50),
                                    Color.clear
                                ]),
                                center: CGPoint(x: rect.midX, y: rect.midY),
                                startRadius: 1,
                                endRadius: radius
                            )
                        )
                    }

                    // LAYER 3: Foreground Depth-of-field Flakes (12 large soft flakes)
                    let fgCount = 12
                    for i in 0..<fgCount {
                        let seed = Double(i + 160)
                        let speed = 72.0 + (seed.truncatingRemainder(dividingBy: 3)) * 24.0
                        let xBase = (seed * 0.223).truncatingRemainder(dividingBy: 1.0) * width
                        let xSway = sin(elapsed * 1.6 + seed * 1.2) * 32.0
                        let x = xBase + xSway
                        let y = (elapsed * speed + seed * 53.0).truncatingRemainder(dividingBy: Double(totalH)) - 35.0
                        let radius = 6.5 + (seed.truncatingRemainder(dividingBy: 3)) * 3.0

                        let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [
                                    Color.white.opacity(0.65),
                                    Color.white.opacity(0.25),
                                    Color.clear
                                ]),
                                center: CGPoint(x: rect.midX, y: rect.midY),
                                startRadius: 2,
                                endRadius: radius
                            )
                        )
                    }

                    // 4. Cold atmospheric bottom mist
                    let frostRect = CGRect(x: 0, y: height * 0.85, width: width, height: height * 0.15)
                    var frostPath = Path()
                    frostPath.addRect(frostRect)
                    context.fill(
                        frostPath,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.18)
                            ]),
                            startPoint: CGPoint(x: width * 0.5, y: frostRect.minY),
                            endPoint: CGPoint(x: width * 0.5, y: frostRect.maxY)
                        )
                    )
                }
            }
        }
    }

    // MARK: - 7. Photorealistic Fog Sky (Pure Metal Atmospheric Volumetric Fog Deck)

    private func photorealisticFogSky(in size: CGSize) -> some View {
        AtmosphericFogView(
            mode: .fog,
            baseDensity: isNight ? 0.75 : 0.85,
            scatteringFactor: isNight ? 1.2 : 1.45,
            ambientColor: isNight ? (0.45, 0.52, 0.65) : (0.84, 0.88, 0.94)
        )
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    // MARK: - 8. Photorealistic Moon Sky (Physically-Based 3D Spherical Moon in Metal)

    private func photorealisticMoonSky(in size: CGSize) -> some View {
        let aspect = Float(size.width / size.height)
        let moonRay = CelestialAtmosphereEngine.rayDirection(for: CGPoint(x: 0.70, y: 0.20), aspect: aspect)

        return CelestialAtmosphereView(
            isNight: true,
            moonDir: moonRay,
            moonToSunDir: resolvedMoonToSunDir,
            moonPhase: resolvedMoonPhase,
            debugMode: celestialDebugMode
        )
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}
