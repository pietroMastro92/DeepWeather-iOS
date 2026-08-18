import SwiftUI

// MARK: - Animated Weather Background View

/// Photorealistic atmospheric animated background matching Apple Weather design standards:
/// - Sunny: Pure radiant solar disc with atmospheric Rayleigh scattering dome, optical prismatic diffraction halo, and soft lens bokeh. Free of unnatural lines or streaks.
/// - Cloudy: Hyper-realistic volumetric stratocumulus billows with silver sunlit rims, shaded slate-grey bellies, 3-layer parallax depth, and organic harmonic breathing.
/// - Rain: 3D multi-layered cinematic rainfall with wind-slanted motion blur streaks, distant drizzle curtains, foreground refractive heavy drops, and low-altitude splash mist.
/// - Storm: Cinematic heavy rain with dual-flash atmospheric lightning illumination.
/// - Fog, Snow, and Celestial Star matrix.
/// Fully respects Reduce Motion for accessibility.
struct AnimatedWeatherBackgroundView: View {
    let gradient: [Color]
    let isNight: Bool
    var showsStars: Bool = false
    var weatherKind: WeatherAnimationKind = .cloud

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var solarPulse: Double = 1.0
    @State private var lightningFlash: Double = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // Base Daylight/Night sky atmospheric gradient
                LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)

                if !reduceMotion {
                    switch weatherKind {
                    case .sun:
                        photorealisticSunSky(in: size)
                    case .cloud:
                        photorealisticCloudSky(in: size)
                    case .moon:
                        photorealisticMoonSky(in: size)
                    case .fog:
                        photorealisticFogSky(in: size)
                    case .rain:
                        photorealisticRainSky(in: size)
                    case .snow:
                        snowEffect(in: size)
                    case .storm:
                        stormEffect(in: size)
                    }

                    // Celestial stars on clear night skies
                    if (showsStars || isNight) && weatherKind != .fog && weatherKind != .rain && weatherKind != .storm && weatherKind != .cloud {
                        starsMatrix(in: size)
                    }
                }
            }
        }
    }

    // MARK: - Photorealistic Sunny Sky (Pure Celestial Orb & Rayleigh Scattering)

    private func photorealisticSunSky(in size: CGSize) -> some View {
        let sunOrigin = CGPoint(x: size.width * 0.35, y: size.height * 0.10)

        return TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.96 + 0.04 * sin(elapsed * 0.7)

            ZStack {
                // 1. Broad Sky Illumination Dome (Atmospheric Rayleigh scattering glow)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color(red: 0.95, green: 0.98, blue: 1.0).opacity(0.26),
                                Color(red: 0.50, green: 0.75, blue: 1.0).opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: size.width * 1.1
                        )
                    )
                    .frame(width: size.width * 2.2, height: size.width * 2.2)
                    .position(sunOrigin)
                    .blur(radius: 30)

                // 2. Solar Core Plasma Flare (Radiant bright sun disc)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.96),
                                Color(red: 1.0, green: 0.98, blue: 0.88).opacity(0.65),
                                Color(red: 1.0, green: 0.85, blue: 0.50).opacity(0.22),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 75
                        )
                    )
                    .frame(width: 150, height: 150)
                    .position(sunOrigin)
                    .scaleEffect(pulse)
                    .blur(radius: 8)

                // 3. Optical Rainbow Diffraction Ring (Prismatic lens halo)
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.20),
                                Color(red: 0.55, green: 0.95, blue: 0.65).opacity(0.16),
                                Color(red: 1.0, green: 0.90, blue: 0.40).opacity(0.22),
                                Color(red: 1.0, green: 0.50, blue: 0.35).opacity(0.16),
                                Color(red: 0.75, green: 0.45, blue: 0.95).opacity(0.14),
                                Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.20)
                            ],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: size.width * 0.72, height: size.width * 0.72)
                    .position(sunOrigin)
                    .scaleEffect(0.97 + 0.04 * sin(elapsed * 0.5))
                    .blur(radius: 5)

                // 4. Secondary Optical Bokeh Disc (Floating naturally along optical axis)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.14),
                                Color(red: 0.35, green: 0.65, blue: 0.95).opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: size.width * 0.16
                        )
                    )
                    .frame(width: size.width * 0.32, height: size.width * 0.32)
                    .position(x: size.width * 0.68, y: size.height * 0.42)
                    .scaleEffect(0.96 + 0.05 * cos(elapsed * 0.4))
                    .blur(radius: 8)
            }
        }
    }

    // MARK: - Photorealistic Cloudy Sky (Volumetric Multi-Cluster Billows & Organic Shading)

    private func photorealisticCloudSky(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let width = canvasSize.width
                let height = canvasSize.height
                let totalSpan = width + 700

                // 1. Ambient Sun Filtration (Sunlight diffusing behind upper cloud layer)
                let sunDiffRect = CGRect(x: width * 0.18, y: height * 0.02, width: width * 0.68, height: height * 0.38)
                context.fill(
                    Path(ellipseIn: sunDiffRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.35),
                            Color(red: 1.0, green: 0.97, blue: 0.90).opacity(0.18),
                            Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.08),
                            Color.clear
                        ]),
                        center: CGPoint(x: sunDiffRect.midX, y: sunDiffRect.midY),
                        startRadius: 20,
                        endRadius: width * 0.42
                    )
                )

                // 2. LAYER 1: Deep Stratiform Cloud Deck (Background Mist - Slow, Broad & Smooth)
                let layer1Masses = [
                    (baseX: 0.00, baseY: 0.04, w: 480.0, h: 220.0, speed: 3.5, opacity: 0.25),
                    (baseX: 0.38, baseY: 0.10, w: 540.0, h: 250.0, speed: 4.0, opacity: 0.30),
                    (baseX: 0.72, baseY: 0.06, w: 500.0, h: 230.0, speed: 3.8, opacity: 0.28)
                ]

                for (idx, mass) in layer1Masses.enumerated() {
                    let seed = Double(idx)
                    let xOffset = (elapsed * mass.speed + mass.baseX * totalSpan).truncatingRemainder(dividingBy: totalSpan) - 350
                    let undulation = sin(elapsed * 0.12 + seed * 1.7) * 12.0
                    let rect = CGRect(x: xOffset, y: height * mass.baseY + undulation, width: mass.w, height: mass.h)

                    // Layer 1 volumetric body
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.white.opacity(mass.opacity * 1.15),
                                Color(red: 0.76, green: 0.82, blue: 0.90).opacity(mass.opacity * 0.85),
                                Color(red: 0.60, green: 0.68, blue: 0.78).opacity(mass.opacity * 0.40),
                                Color.clear
                            ]),
                            startPoint: CGPoint(x: rect.midX, y: rect.minY),
                            endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                        )
                    )
                }

                // 3. LAYER 2: Main Mid-Atmosphere Volumetric Cloud Clusters (Organic Multi-Lobe Cumulus)
                // Each cloud cluster is composed of 3 connected harmonic billows for natural organic silhouette
                let layer2Clusters = [
                    (baseX: 0.08, baseY: 0.12, baseW: 360.0, baseH: 160.0, speed: 6.8, opacity: 0.38),
                    (baseX: 0.42, baseY: 0.18, baseW: 410.0, baseH: 180.0, speed: 7.5, opacity: 0.42),
                    (baseX: 0.78, baseY: 0.14, baseW: 380.0, baseH: 165.0, speed: 7.0, opacity: 0.36),
                    (baseX: 0.24, baseY: 0.24, baseW: 340.0, baseH: 150.0, speed: 8.0, opacity: 0.32)
                ]

                for (cIdx, cluster) in layer2Clusters.enumerated() {
                    let seed = Double(cIdx)
                    let clusterX = (elapsed * cluster.speed + cluster.baseX * totalSpan).truncatingRemainder(dividingBy: totalSpan) - 350
                    let breathe = sin(elapsed * 0.20 + seed * 1.4) * 9.0
                    let clusterY = height * cluster.baseY + breathe

                    // Sub-lobes within the cluster for realistic cumulus fluffiness
                    let lobes = [
                        (dx: 0.0, dy: 0.0, scaleW: 1.0, scaleH: 1.0),
                        (dx: cluster.baseW * 0.25, dy: -cluster.baseH * 0.15, scaleW: 0.75, scaleH: 0.80),
                        (dx: -cluster.baseW * 0.22, dy: cluster.baseH * 0.10, scaleW: 0.80, scaleH: 0.75)
                    ]

                    for (lIdx, lobe) in lobes.enumerated() {
                        let lSeed = Double(lIdx)
                        let lobeW = cluster.baseW * lobe.scaleW
                        let lobeH = cluster.baseH * lobe.scaleH
                        let lobeX = clusterX + lobe.dx + sin(elapsed * 0.28 + seed + lSeed) * 4.0
                        let lobeY = clusterY + lobe.dy
                        let rect = CGRect(x: lobeX - lobeW * 0.5, y: lobeY - lobeH * 0.5, width: lobeW, height: lobeH)

                        // 3A. Silver Illuminated Sunlit Top Lobe
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .radialGradient(
                                Gradient(colors: [
                                    Color.white.opacity(cluster.opacity),
                                    Color(red: 0.88, green: 0.92, blue: 0.97).opacity(cluster.opacity * 0.75),
                                    Color(red: 0.72, green: 0.79, blue: 0.88).opacity(cluster.opacity * 0.45),
                                    Color.clear
                                ]),
                                center: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.32),
                                startRadius: 18,
                                endRadius: lobeW * 0.52
                            )
                        )

                        // 3B. Volumetric Shaded Belly (Cool slate-grey undercut)
                        let bellyRect = CGRect(x: rect.minX + 15, y: rect.midY - 5, width: rect.width - 30, height: rect.height * 0.55)
                        context.fill(
                            Path(ellipseIn: bellyRect),
                            with: .radialGradient(
                                Gradient(colors: [
                                    Color(red: 0.48, green: 0.56, blue: 0.68).opacity(cluster.opacity * 0.40),
                                    Color(red: 0.58, green: 0.66, blue: 0.76).opacity(cluster.opacity * 0.18),
                                    Color.clear
                                ]),
                                center: CGPoint(x: bellyRect.midX, y: bellyRect.maxY - 8),
                                startRadius: 8,
                                endRadius: bellyRect.width * 0.48
                            )
                        )
                    }
                }

                // 4. LAYER 3: Low-Altitude Foreground Scud Mist & Silky Shreds (Fast Drifting Vapor)
                let layer3Strata = [
                    (baseX: 0.05, baseY: 0.28, w: 460.0, h: 85.0, speed: 13.5, opacity: 0.20),
                    (baseX: 0.52, baseY: 0.36, w: 500.0, h: 95.0, speed: 15.0, opacity: 0.22),
                    (baseX: 0.88, baseY: 0.26, w: 440.0, h: 80.0, speed: 12.8, opacity: 0.18)
                ]

                for (idx, strata) in layer3Strata.enumerated() {
                    let seed = Double(idx)
                    let xOffset = (elapsed * strata.speed + strata.baseX * totalSpan).truncatingRemainder(dividingBy: totalSpan) - 350
                    let yOffset = height * strata.baseY + cos(elapsed * 0.26 + seed * 1.5) * 8.0
                    let rect = CGRect(x: xOffset, y: yOffset, width: strata.w, height: strata.h)

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color.white.opacity(strata.opacity * 1.1),
                                Color(red: 0.90, green: 0.94, blue: 0.98).opacity(strata.opacity * 0.6),
                                Color.clear
                            ]),
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 12,
                            endRadius: strata.w * 0.50
                        )
                    )
                }
            }
        }
    }

    // MARK: - Photorealistic Rain Sky (Multi-layered 3D Precipitation, Wind Angle & Splash Vapor)

    private func photorealisticRainSky(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let width = canvasSize.width
                let height = canvasSize.height
                let totalHeight = height + 120
                let windSlantX = -4.2 // Natural wind angle tilt for raindrops

                // 1. Dark Atmospheric Rain Cloud Deck & Horizontal Mist Bands
                let mistBands = 4
                for i in 0..<mistBands {
                    let seed = Double(i)
                    let x = (elapsed * (10.0 + seed * 3.5) + seed * 140.0).truncatingRemainder(dividingBy: width + 400) - 200
                    let y = height * (0.08 + seed * 0.16) + sin(elapsed * 0.35 + seed) * 12.0
                    let w = width * 1.5
                    let h = 100.0 + seed * 30.0

                    let rect = CGRect(x: x, y: y, width: w, height: h)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 0.42, green: 0.50, blue: 0.62).opacity(0.25),
                                Color(red: 0.30, green: 0.38, blue: 0.48).opacity(0.12),
                                Color.clear
                            ]),
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 15,
                            endRadius: w * 0.50
                        )
                    )
                }

                // 2. LAYER 1: Background Fine Drizzle Sheets (110+ high-speed micro-streaks)
                let bgCount = 110
                for i in 0..<bgCount {
                    let seed = Double(i)
                    let speed = 520.0 + (seed.truncatingRemainder(dividingBy: 8)) * 40.0
                    let xBase = (seed * 0.073).truncatingRemainder(dividingBy: 1.0) * (width + 80) - 40
                    let yPos = (elapsed * speed + seed * 41.0).truncatingRemainder(dividingBy: totalHeight) - 60

                    let dropLength = 16.0 + (seed.truncatingRemainder(dividingBy: 4)) * 6.0
                    var path = Path()
                    path.move(to: CGPoint(x: xBase, y: yPos))
                    path.addLine(to: CGPoint(x: xBase + windSlantX * (dropLength / 18.0), y: yPos + dropLength))

                    let opacity = 0.18 + (seed.truncatingRemainder(dividingBy: 4)) * 0.08
                    context.stroke(
                        path,
                        with: .color(Color.white.opacity(opacity)),
                        lineWidth: 1.0
                    )
                }

                // 3. LAYER 2: Midground Dynamic Raindrops (70 streaks with motion-blur opacity gradient)
                let midCount = 70
                for i in 0..<midCount {
                    let seed = Double(i + 120)
                    let speed = 720.0 + (seed.truncatingRemainder(dividingBy: 7)) * 55.0
                    let xBase = (seed * 0.113).truncatingRemainder(dividingBy: 1.0) * (width + 90) - 45
                    let yPos = (elapsed * speed + seed * 59.0).truncatingRemainder(dividingBy: totalHeight) - 70

                    let dropLength = 26.0 + (seed.truncatingRemainder(dividingBy: 5)) * 10.0
                    let startPoint = CGPoint(x: xBase, y: yPos)
                    let endPoint = CGPoint(x: xBase + windSlantX * (dropLength / 20.0), y: yPos + dropLength)

                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)

                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.white.opacity(0.06),
                                Color(red: 0.88, green: 0.95, blue: 1.0).opacity(0.42)
                            ]),
                            startPoint: startPoint,
                            endPoint: endPoint
                        ),
                        lineWidth: 1.6
                    )
                }

                // 4. LAYER 3: Foreground Cinematic Heavy Drops (32 refractive high-velocity drops)
                let fgCount = 32
                for i in 0..<fgCount {
                    let seed = Double(i + 250)
                    let speed = 920.0 + (seed.truncatingRemainder(dividingBy: 5)) * 75.0
                    let xBase = (seed * 0.163).truncatingRemainder(dividingBy: 1.0) * (width + 100) - 50
                    let yPos = (elapsed * speed + seed * 73.0).truncatingRemainder(dividingBy: totalHeight) - 80

                    let dropLength = 38.0 + (seed.truncatingRemainder(dividingBy: 4)) * 14.0
                    let startPoint = CGPoint(x: xBase, y: yPos)
                    let endPoint = CGPoint(x: xBase + windSlantX * (dropLength / 22.0), y: yPos + dropLength)

                    var path = Path()
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)

                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [
                                Color.white.opacity(0.10),
                                Color(red: 0.92, green: 0.97, blue: 1.0).opacity(0.65)
                            ]),
                            startPoint: startPoint,
                            endPoint: endPoint
                        ),
                        lineWidth: 2.2
                    )
                }

                // 5. Ground Splash Mist & Bottom Surface Vapor Fog
                let splashHazeRect = CGRect(x: 0, y: height * 0.82, width: width, height: height * 0.18)
                var splashPath = Path()
                splashPath.addRect(splashHazeRect)
                context.fill(
                    splashPath,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.clear,
                            Color(red: 0.70, green: 0.80, blue: 0.92).opacity(0.12),
                            Color.white.opacity(0.20)
                        ]),
                        startPoint: CGPoint(x: width * 0.5, y: splashHazeRect.minY),
                        endPoint: CGPoint(x: width * 0.5, y: splashHazeRect.maxY)
                    )
                )
            }
        }
    }

    // MARK: - Photorealistic Moon Sky

    private func photorealisticMoonSky(in size: CGSize) -> some View {
        let moonOrigin = CGPoint(x: size.width * 0.80, y: size.height * 0.18)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.35),
                            Color(red: 0.40, green: 0.60, blue: 0.95).opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: size.width * 0.55
                    )
                )
                .frame(width: size.width * 1.1, height: size.width * 1.1)
                .position(moonOrigin)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color(red: 0.88, green: 0.94, blue: 1.0).opacity(0.40),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 45
                    )
                )
                .frame(width: 90, height: 90)
                .position(moonOrigin)
                .blur(radius: 6)
        }
    }

    // MARK: - Photorealistic Fog Sky

    private func photorealisticFogSky(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let count = 5
                for i in 0..<count {
                    let seed = Double(i)
                    let speed = 10.0 + seed * 3.0
                    let total = canvasSize.width + 200
                    let x = (elapsed * speed + seed * (total / Double(count))).truncatingRemainder(dividingBy: total) - 100
                    let y = canvasSize.height * (0.22 + seed * 0.15) + sin(elapsed * 0.35 + seed) * 14.0
                    let w = canvasSize.width * 1.5
                    let h = 75.0 + seed * 16.0

                    let rect = CGRect(x: x - w * 0.5, y: y - h * 0.5, width: w, height: h)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.06),
                                Color.clear
                            ]),
                            center: CGPoint(x: rect.midX, y: rect.midY),
                            startRadius: 10,
                            endRadius: w * 0.5
                        )
                    )
                }
            }
        }
    }

    // MARK: - Snow Particles

    private func snowEffect(in size: CGSize) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let count = 32
                for i in 0..<count {
                    let seed = Double(i)
                    let speed = 42.0 + (seed.truncatingRemainder(dividingBy: 4)) * 22.0
                    let xBase = (seed * 0.173).truncatingRemainder(dividingBy: 1.0) * canvasSize.width
                    let xWobble = sin(elapsed * 1.5 + seed) * 16.0
                    let x = xBase + xWobble
                    let y = (elapsed * speed + seed * 33.0).truncatingRemainder(dividingBy: Double(canvasSize.height + 40)) - 20
                    let radius = 2.0 + (seed.truncatingRemainder(dividingBy: 3)) * 1.6

                    let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.45 + (seed.truncatingRemainder(dividingBy: 3)) * 0.15)))
                }
            }
        }
    }

    // MARK: - Storm Effect

    private func stormEffect(in size: CGSize) -> some View {
        ZStack {
            photorealisticRainSky(in: size)

            // Lightning Flash Overlay
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
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            let randomDelay = Double.random(in: 4.0...9.0)
            try? await Task.sleep(for: .milliseconds(Int(randomDelay * 1000)))
            guard !Task.isCancelled, !reduceMotion else { break }

            // Double flash
            withAnimation(.easeIn(duration: 0.08)) { lightningFlash = 0.55 }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.easeOut(duration: 0.1)) { lightningFlash = 0.0 }
            try? await Task.sleep(for: .milliseconds(70))
            withAnimation(.easeIn(duration: 0.06)) { lightningFlash = 0.75 }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.35)) { lightningFlash = 0.0 }
        }
    }

    // MARK: - Stars Matrix

    private func starsMatrix(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 8 + CGFloat(index % 3) * 5))
                    .foregroundStyle(.white.opacity(0.6))
                    .symbolEffect(
                        .pulse,
                        options: .speed(0.6 + Double(index) * 0.2).repeating
                    )
                    .position(
                        x: size.width * (0.08 + 0.12 * CGFloat(index)),
                        y: size.height * (0.06 + 0.11 * CGFloat(index % 4))
                    )
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
