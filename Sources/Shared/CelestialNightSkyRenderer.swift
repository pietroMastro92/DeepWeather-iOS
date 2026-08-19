import SwiftUI
import Metal
import MetalKit

// MARK: - Celestial Night Sky Render Mode

public enum CelestialRenderMode: Int32, Sendable, CaseIterable, Identifiable {
    case starFieldOnly = 0
    case milkyWayOnly = 1
    case composite = 2

    public var id: Int32 { rawValue }

    public var title: String {
        switch self {
        case .starFieldOnly: return "Stelle"
        case .milkyWayOnly: return "Via Lattea"
        case .composite: return "Composito"
        }
    }
}

// MARK: - Metal Celestial Night Sky Uniforms

public struct CelestialNightSkyUniforms {
    public var resolution: (Float, Float)
    public var displayScale: Float
    public var time: Float
    public var moonPos: (Float, Float)
    public var moonBrightness: Float
    public var milkyWayIntensity: Float
    public var starIntensity: Float
    public var limitingMagnitude: Float
    public var renderMode: Int32
    public var pad0: Float = 0
    public var pad1: Float = 0
    public var pad2: Float = 0

    public init(
        resolution: (Float, Float) = (1170, 2532),
        displayScale: Float = 3.0,
        time: Float = 0.0,
        moonPos: (Float, Float) = (0.78, 0.14),
        moonBrightness: Float = 1.0,
        milkyWayIntensity: Float = 0.45,
        starIntensity: Float = 1.0,
        limitingMagnitude: Float = 5.2,
        renderMode: CelestialRenderMode = .composite
    ) {
        self.resolution = resolution
        self.displayScale = displayScale
        self.time = time
        self.moonPos = moonPos
        self.moonBrightness = moonBrightness
        self.milkyWayIntensity = milkyWayIntensity
        self.starIntensity = starIntensity
        self.limitingMagnitude = limitingMagnitude
        self.renderMode = renderMode.rawValue
    }
}

// MARK: - Astronomical Star Definition

public struct CelestialStarVertex {
    public var position: (Float, Float) // Normalized celestial coordinates [0, 1]
    public var magnitude: Float        // Apparent magnitude (-0.5 to 5.8)
    public var colorRGB: (Float, Float, Float) // Low-saturation spectral color
    public var twinklePhase: Float
    public var twinkleSpeed: Float

    public init(
        position: (Float, Float),
        magnitude: Float,
        colorRGB: (Float, Float, Float),
        twinklePhase: Float,
        twinkleSpeed: Float
    ) {
        self.position = position
        self.magnitude = magnitude
        self.colorRGB = colorRGB
        self.twinklePhase = twinklePhase
        self.twinkleSpeed = twinkleSpeed
    }
}

// MARK: - Metal Celestial Night Sky Engine

@MainActor
public final class CelestialNightSkyEngine {
    public static let shared = CelestialNightSkyEngine()

    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    private(set) var milkyWayPipelineState: MTLRenderPipelineState?
    private(set) var starPipelineState: MTLRenderPipelineState?
    private(set) var starVertexBuffer: MTLBuffer?
    public private(set) var starCount: Int = 0
    public private(set) var isInitialized: Bool = false

    private init() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            self.device = nil
            self.commandQueue = nil
            return
        }
        self.device = defaultDevice
        self.commandQueue = defaultDevice.makeCommandQueue()
        self.setupEngine()
    }

    private func setupEngine() {
        guard let device = device else { return }

        // 1. Generate ~450 Curated Astronomical Stars
        var stars: [CelestialStarVertex] = []
        stars.reserveCapacity(500)

        var rngSeed: UInt64 = 543219876
        func nextRandom() -> Float {
            rngSeed = (rngSeed &* 6364136223846793005 &+ 1442695040888963407)
            let val = (rngSeed >> 32) & 0xFFFFFF
            return Float(val) / Float(0xFFFFFF)
        }

        let galAngle: Float = 0.62
        let cosG = cos(galAngle)
        let sinG = sin(galAngle)

        for _ in 0..<480 {
            let x = nextRandom()
            let yRaw = nextRandom()
            let y = pow(yRaw, 1.10) * 0.90 // full celestial dome

            let cx = (x - 0.48) * (540.0 / 960.0)
            let cy = y - 0.38
            let rotX = cx * cosG - cy * sinG
            let rotY = cx * sinG + cy * cosG
            let arcCurve = rotX * rotX * 0.32 - rotX * 0.12
            let galDist = abs(rotY - arcCurve)

            // Mild galactic concentration, plenty in open sky
            let keepChance: Float = galDist < 0.25 ? 0.95 : 0.68
            if nextRandom() > keepChance {
                continue
            }

            let roll = nextRandom()
            let mag: Float
            if roll < 0.04 {
                // First magnitude bright stars (Vega, Sirius, Arcturus, Rigel): 0.1 to 1.1
                mag = 0.1 + nextRandom() * 1.0
            } else if roll < 0.18 {
                // Navigational visible stars: 1.2 to 2.5
                mag = 1.2 + nextRandom() * 1.3
            } else if roll < 0.58 {
                // Standard visible stars: 2.6 to 3.8
                mag = 2.6 + nextRandom() * 1.2
            } else {
                // Faint backdrop stars: 3.9 to 5.1
                mag = 3.9 + nextRandom() * 1.2
            }

            // Spectral color temperature (realistic subtle saturation)
            let colorRoll = nextRandom()
            let color: (Float, Float, Float)
            if colorRoll < 0.25 {
                color = (0.88, 0.94, 1.0) // B/A pale blue-white
            } else if colorRoll < 0.72 {
                color = (0.98, 0.99, 1.0) // F/G pure diamond white
            } else {
                color = (1.0, 0.96, 0.90) // K/M pale warm amber
            }

            let phase = nextRandom() * Float.pi * 2.0
            let speed = 0.35 + nextRandom() * 0.55 // Slow, organic scintillation

            stars.append(CelestialStarVertex(
                position: (x, y),
                magnitude: mag,
                colorRGB: color,
                twinklePhase: phase,
                twinkleSpeed: speed
            ))
        }

        self.starCount = stars.count
        self.starVertexBuffer = device.makeBuffer(
            bytes: stars,
            length: stars.count * MemoryLayout<CelestialStarVertex>.stride,
            options: .storageModeShared
        )

        // 2. Metal Shaders for Clean Milky Way & Point-Source Starfield
        let mslSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct CelestialNightSkyUniforms {
            float2 resolution;
            float displayScale;
            float time;
            float2 moonPos;
            float moonBrightness;
            float milkyWayIntensity;
            float starIntensity;
            float limitingMagnitude;
            int renderMode;
            float pad0;
            float pad1;
            float pad2;
        };

        struct StarVertex {
            float2 position;
            float magnitude;
            float3 colorRGB;
            float twinklePhase;
            float twinkleSpeed;
        };

        struct FullscreenVertexOut {
            float4 position [[position]];
            float2 uv;
        };

        struct StarVertexOut {
            float4 position [[position]];
            float2 pixelOffset;
            float4 color;
            float magnitude;
        };

        inline float hash21(float2 p) {
            p = fract(p * float2(123.34, 456.21));
            p += dot(p, p + 45.32);
            return fract(p.x * p.y);
        }

        inline float smoothNoise2D(float2 p) {
            float2 i = floor(p);
            float2 f = fract(p);
            float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
            float n00 = hash21(i + float2(0.0, 0.0));
            float n10 = hash21(i + float2(1.0, 0.0));
            float n01 = hash21(i + float2(0.0, 1.0));
            float n11 = hash21(i + float2(1.0, 1.0));
            return mix(mix(n00, n10, u.x), mix(n01, n11, u.x), u.y);
        }

        inline float macroFBM(float2 p) {
            float v = 0.0;
            float a = 0.55;
            for (int i = 0; i < 3; ++i) {
                v += a * smoothNoise2D(p);
                p = p * 2.05 + float2(1.7, 9.2);
                a *= 0.45;
            }
            return v;
        }

        vertex FullscreenVertexOut milkyWayVertex(uint vertexID [[vertex_id]]) {
            FullscreenVertexOut out;
            float2 grid = float2((vertexID << 1) & 2, vertexID & 2);
            out.position = float4(grid * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
            out.uv = grid;
            return out;
        }

        // 🌌 Macro-Scale Smooth Milky Way Fragment Shader (ZERO pixel grain)
        fragment half4 milkyWayFragment(
            FullscreenVertexOut in [[stage_in]],
            constant CelestialNightSkyUniforms &uniforms [[buffer(0)]]
        ) {
            if (uniforms.renderMode == 0) {
                return half4(0.0);
            }

            float2 uv = in.uv;
            float aspect = uniforms.resolution.x / uniforms.resolution.y;

            float2 centered = uv - float2(0.48, 0.38);
            centered.x *= aspect;

            float angle = 0.62;
            float cosA = cos(angle);
            float sinA = sin(angle);
            float2 rotated = float2(centered.x * cosA - centered.y * sinA, centered.x * sinA + centered.y * cosA);

            float arcCurve = rotated.x * rotated.x * 0.32 - rotated.x * 0.12;
            float galDist = abs(rotated.y - arcCurve);
            float galLong = rotated.x + 0.5;

            if (galDist > 0.48) {
                return half4(0.0);
            }

            // 1. Broad Gaussian Disk Profile
            float diskProfile = exp(-galDist * galDist * 18.0);
            float coreBulge = exp(-length(rotated - float2(-0.06, 0.02)) * 2.8) * 0.60;
            float baseGlow = (diskProfile * 0.70 + coreBulge) * smoothstep(0.48, 0.06, galDist);

            // 2. Low-Frequency Nebular Structures
            float2 nebCoord = float2(galLong * 3.0, (rotated.y - arcCurve) * 5.0);
            float nebulae = macroFBM(nebCoord);

            // 3. Macro Dark Dust Lanes (Great Rift Absorption)
            float2 dustCoord = float2(galLong * 3.5 + 5.2, (rotated.y - arcCurve) * 7.5 + 2.1);
            float dustNoise = macroFBM(dustCoord);
            float dustLanes = smoothstep(0.36, 0.66, dustNoise);
            float absorption = 1.0 - dustLanes * 0.75 * smoothstep(0.22, 0.02, galDist);

            float totalLuminance = baseGlow * (0.35 + nebulae * 0.80) * absorption;

            // 4. LOCAL Lunar Falloff (narrow radius) & Horizon Attenuation
            float distToMoon = length((uv - uniforms.moonPos) * float2(aspect, 1.0));
            float lunarDimming = smoothstep(0.05, 0.22, distToMoon);
            float horizonDimming = smoothstep(0.92, 0.62, uv.y);

            totalLuminance *= uniforms.milkyWayIntensity * lunarDimming * horizonDimming;

            if (totalLuminance <= 0.001) {
                return half4(0.0);
            }

            half3 coreColor = half3(0.95, 0.93, 0.88);
            half3 armColor = half3(0.82, 0.88, 1.0);
            half3 galColor = mix(armColor, coreColor, half(coreBulge * 1.4));

            return half4(galColor * half(totalLuminance * 0.55), half(totalLuminance * 0.65));
        }

        // 🌟 Precise Point Spread Function (PSF) Starfield
        vertex StarVertexOut starPointVertex(
            uint vertexID [[vertex_id]],
            uint instanceID [[instance_id]],
            constant StarVertex *starArray [[buffer(0)]],
            constant CelestialNightSkyUniforms &uniforms [[buffer(1)]]
        ) {
            StarVertexOut out;

            if (uniforms.renderMode == 1) {
                out.position = float4(2.0, 2.0, 2.0, 1.0);
                out.pixelOffset = float2(0.0);
                out.color = float4(0.0);
                out.magnitude = 100.0;
                return out;
            }

            StarVertex star = starArray[instanceID];

            float limMag = uniforms.limitingMagnitude;
            if (star.magnitude > limMag) {
                out.position = float4(2.0, 2.0, 2.0, 1.0);
                out.pixelOffset = float2(0.0);
                out.color = float4(0.0);
                out.magnitude = star.magnitude;
                return out;
            }

            // Atmospheric scintillation (twinkle): subtle, slow
            float twinkle = 1.0 + 0.04 * sin(uniforms.time * star.twinkleSpeed + star.twinklePhase);

            // Photographic exposure luminance mapping: clearly visible pinpricks on iPhone display
            float flux = pow(10.0, -0.4 * (star.magnitude - 0.5));
            float brightness = clamp(pow(flux, 0.28) * 0.95, 0.25, 1.0) * uniforms.starIntensity * twinkle;

            // LOCAL Lunar Glare attenuation (strictly localized around the moon disc)
            float aspect = uniforms.resolution.x / uniforms.resolution.y;
            float distToMoon = length((star.position - uniforms.moonPos) * float2(aspect, 1.0));
            float lunarMask = smoothstep(0.04, 0.16, distToMoon);
            brightness *= lunarMask;

            float horizonMask = smoothstep(0.94, 0.68, star.position.y);
            brightness *= horizonMask;

            if (brightness <= 0.01) {
                out.position = float4(2.0, 2.0, 2.0, 1.0);
                out.pixelOffset = float2(0.0);
                out.color = float4(0.0);
                out.magnitude = star.magnitude;
                return out;
            }

            // Physical pixel radius for quad
            float quadRadiusPx = (star.magnitude < 1.3) ? 6.0 : 3.2;

            float2 quadOffsets[4] = {
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0,  1.0)
            };
            uint indices[6] = {0, 1, 2, 2, 1, 3};
            float2 corner = quadOffsets[indices[vertexID]];

            float2 starPixelPos = star.position * uniforms.resolution;
            float2 vertexPixelPos = starPixelPos + corner * quadRadiusPx;

            float2 ndcPos = (vertexPixelPos / uniforms.resolution) * 2.0 - 1.0;
            ndcPos.y = -ndcPos.y;

            out.position = float4(ndcPos, 0.0, 1.0);
            out.pixelOffset = corner * quadRadiusPx;
            out.color = float4(star.colorRGB, brightness);
            out.magnitude = star.magnitude;

            return out;
        }

        fragment half4 starPointFragment(
            StarVertexOut in [[stage_in]]
        ) {
            if (in.color.a <= 0.001) {
                discard_fragment();
            }

            float distPxSq = dot(in.pixelOffset, in.pixelOffset);

            // True Sub-Pixel Gaussian Point Spread Function (sigma = 0.78 physical pixels)
            const float sigmaSq = 0.78 * 0.78;
            float corePSF = exp(-distPxSq / (2.0 * sigmaSq));

            // Optical diffraction halo only for brightest first-magnitude stars (mag < 1.3)
            float halo = 0.0;
            if (in.magnitude < 1.3) {
                const float haloSigmaSq = 3.0 * 3.0;
                halo = 0.12 * exp(-distPxSq / (2.0 * haloSigmaSq));
            }

            float totalAlpha = saturate((corePSF + halo) * in.color.a);

            if (totalAlpha <= 0.003) {
                discard_fragment();
            }

            half3 starCol = half3(in.color.rgb);
            return half4(starCol * half(totalAlpha), half(totalAlpha));
        }
        """

        do {
            let library = try device.makeLibrary(source: mslSource, options: nil)

            // Milky Way Render Pipeline
            let mwDesc = MTLRenderPipelineDescriptor()
            mwDesc.vertexFunction = library.makeFunction(name: "milkyWayVertex")
            mwDesc.fragmentFunction = library.makeFunction(name: "milkyWayFragment")
            mwDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            mwDesc.colorAttachments[0].isBlendingEnabled = true
            mwDesc.colorAttachments[0].sourceRGBBlendFactor = .one
            mwDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            mwDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            mwDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            self.milkyWayPipelineState = try device.makeRenderPipelineState(descriptor: mwDesc)

            // Starfield Render Pipeline
            let starPipeDesc = MTLRenderPipelineDescriptor()
            starPipeDesc.vertexFunction = library.makeFunction(name: "starPointVertex")
            starPipeDesc.fragmentFunction = library.makeFunction(name: "starPointFragment")
            starPipeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            starPipeDesc.colorAttachments[0].isBlendingEnabled = true
            starPipeDesc.colorAttachments[0].sourceRGBBlendFactor = .one
            starPipeDesc.colorAttachments[0].destinationRGBBlendFactor = .one
            starPipeDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            starPipeDesc.colorAttachments[0].destinationAlphaBlendFactor = .one
            self.starPipelineState = try device.makeRenderPipelineState(descriptor: starPipeDesc)

            self.isInitialized = true
        } catch {
            print("CelestialNightSkyEngine failed to compile shaders: \(error)")
        }
    }
}

// MARK: - SwiftUI Metal Celestial Night Sky View

public struct CelestialNightSkyView: UIViewRepresentable {
    public var moonPos: (Float, Float)
    public var moonBrightness: Float
    public var milkyWayIntensity: Float
    public var starIntensity: Float
    public var limitingMagnitude: Float
    public var renderMode: CelestialRenderMode

    public init(
        moonPos: (Float, Float) = (0.78, 0.14),
        moonBrightness: Float = 1.0,
        milkyWayIntensity: Float = 0.45,
        starIntensity: Float = 1.0,
        limitingMagnitude: Float = 5.2,
        renderMode: CelestialRenderMode = .composite
    ) {
        self.moonPos = moonPos
        self.moonBrightness = moonBrightness
        self.milkyWayIntensity = milkyWayIntensity
        self.starIntensity = starIntensity
        self.limitingMagnitude = limitingMagnitude
        self.renderMode = renderMode
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = CelestialNightSkyEngine.shared.device
        mtkView.delegate = context.coordinator
        mtkView.backgroundColor = .clear
        mtkView.isOpaque = false
        if let metalLayer = mtkView.layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.magnificationFilter = .linear
            metalLayer.minificationFilter = .linear
        }
        mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0)
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.autoResizeDrawable = true
        mtkView.isPaused = false
        return mtkView
    }

    public func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.moonPos = moonPos
        context.coordinator.moonBrightness = moonBrightness
        context.coordinator.milkyWayIntensity = milkyWayIntensity
        context.coordinator.starIntensity = starIntensity
        context.coordinator.limitingMagnitude = limitingMagnitude
        context.coordinator.renderMode = renderMode
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            moonPos: moonPos,
            moonBrightness: moonBrightness,
            milkyWayIntensity: milkyWayIntensity,
            starIntensity: starIntensity,
            limitingMagnitude: limitingMagnitude,
            renderMode: renderMode
        )
    }

    public final class Coordinator: NSObject, MTKViewDelegate {
        var moonPos: (Float, Float)
        var moonBrightness: Float
        var milkyWayIntensity: Float
        var starIntensity: Float
        var limitingMagnitude: Float
        var renderMode: CelestialRenderMode
        private let startTime = Date.timeIntervalSinceReferenceDate

        init(
            moonPos: (Float, Float),
            moonBrightness: Float,
            milkyWayIntensity: Float,
            starIntensity: Float,
            limitingMagnitude: Float,
            renderMode: CelestialRenderMode
        ) {
            self.moonPos = moonPos
            self.moonBrightness = moonBrightness
            self.milkyWayIntensity = milkyWayIntensity
            self.starIntensity = starIntensity
            self.limitingMagnitude = limitingMagnitude
            self.renderMode = renderMode
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            let width = Float(view.drawableSize.width)
            let height = Float(view.drawableSize.height)
            guard width > 0, height > 0 else { return }

            let engine = MainActor.assumeIsolated({ CelestialNightSkyEngine.shared })
            guard let queue = engine.commandQueue,
                  let mwPipeline = engine.milkyWayPipelineState,
                  let starPipeline = engine.starPipelineState,
                  let starBuffer = engine.starVertexBuffer,
                  let drawable = view.currentDrawable,
                  let renderPass = view.currentRenderPassDescriptor else {
                return
            }

            let elapsed = Float(Date.timeIntervalSinceReferenceDate - startTime)

            var uniforms = CelestialNightSkyUniforms(
                resolution: (width, height),
                displayScale: Float(view.contentScaleFactor),
                time: elapsed,
                moonPos: moonPos,
                moonBrightness: moonBrightness,
                milkyWayIntensity: milkyWayIntensity,
                starIntensity: starIntensity,
                limitingMagnitude: limitingMagnitude,
                renderMode: renderMode
            )

            guard let cmdBuffer = queue.makeCommandBuffer(),
                  let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
                return
            }

            // 1. Render Macro Milky Way (Modes 1 and 2)
            if renderMode == .milkyWayOnly || renderMode == .composite {
                encoder.setRenderPipelineState(mwPipeline)
                encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CelestialNightSkyUniforms>.stride, index: 0)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            }

            // 2. Render Precise Point-Source Stars (Modes 0 and 2)
            if renderMode == .starFieldOnly || renderMode == .composite {
                encoder.setRenderPipelineState(starPipeline)
                encoder.setVertexBuffer(starBuffer, offset: 0, index: 0)
                encoder.setVertexBytes(&uniforms, length: MemoryLayout<CelestialNightSkyUniforms>.stride, index: 1)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: engine.starCount)
            }

            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
    }
}
