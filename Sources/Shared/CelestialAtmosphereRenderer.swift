import SwiftUI
import Metal
import MetalKit

// MARK: - Celestial Atmosphere Debug Mode

public enum CelestialAtmosphereDebugMode: Int32, Sendable, CaseIterable, Identifiable {
    case composite = 0
    case sunDiskOnly = 1
    case sunAndAtmosphere = 2
    case moonDiskOnly = 3
    case moonSurfaceAndPhase = 4
    case moonAndAtmosphere = 5

    public var id: Int32 { rawValue }

    public var title: String {
        switch self {
        case .composite: return "Standard (Composito)"
        case .sunDiskOnly: return "SUN DISK ONLY"
        case .sunAndAtmosphere: return "SUN + ATMOSPHERE"
        case .moonDiskOnly: return "MOON DISK ONLY"
        case .moonSurfaceAndPhase: return "MOON SURFACE + PHASE"
        case .moonAndAtmosphere: return "MOON + ATMOSPHERE"
        }
    }
}

// MARK: - Metal Celestial Atmosphere Uniforms

public struct CelestialAtmosphereUniforms {
    public var resolution: (Float, Float)
    public var time: Float
    public var sunElevation: Float
    public var sunDir: (Float, Float, Float)
    public var pad0: Float = 0
    public var moonDir: (Float, Float, Float)
    public var pad1: Float = 0
    public var moonToSunDir: (Float, Float, Float)
    public var moonPhase: Float
    public var debugMode: Int32
    public var isNight: Float
    public var padding: (Float, Float) = (0, 0)

    public init(
        resolution: (Float, Float) = (1170, 2532),
        time: Float = 0.0,
        sunElevation: Float = 0.75,
        sunDir: (Float, Float, Float) = (-0.0827, 0.7982, 0.5966),
        moonDir: (Float, Float, Float) = (0.091, 0.785, 0.612),
        moonToSunDir: (Float, Float, Float)? = nil,
        moonPhase: Float? = nil,
        debugMode: CelestialAtmosphereDebugMode = .composite,
        isNight: Bool = false
    ) {
        self.resolution = resolution
        self.time = time
        self.sunElevation = sunElevation
        self.sunDir = sunDir
        self.pad0 = 0
        self.moonDir = moonDir
        self.pad1 = 0
        self.moonToSunDir = moonToSunDir ?? LunarPhaseEngine.moonToSunDirection()
        self.moonPhase = moonPhase ?? Float(LunarPhaseEngine.phase())
        self.debugMode = debugMode.rawValue
        self.isNight = isNight ? 1.0 : 0.0
        self.padding = (0, 0)
    }
}

// MARK: - Metal Celestial Atmosphere Engine (Physically-Based Sun & 3D Spherical Moon)

@MainActor
public final class CelestialAtmosphereEngine {
    public static let shared = CelestialAtmosphereEngine()

    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    private(set) var pipelineState: MTLRenderPipelineState?
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

        let mslSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct CelestialAtmosphereUniforms {
            float2 resolution;
            float time;
            float sunElevation;
            packed_float3 sunDir;
            float pad0;
            packed_float3 moonDir;
            float pad1;
            packed_float3 moonToSunDir;
            float moonPhase;
            int debugMode;
            float isNight;
            float2 padding;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        vertex VertexOut celestialVertex(uint vertexID [[vertex_id]]) {
            VertexOut out;
            float2 grid = float2((vertexID << 1) & 2, vertexID & 2);
            out.position = float4(grid * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
            out.uv = grid;
            return out;
        }

        // 3D Procedural Hash & Gradient Noise
        inline float hash31(float3 p) {
            p = fract(p * 0.1031);
            p += dot(p, p.yzx + 33.33);
            return fract((p.x + p.y) * p.z);
        }

        inline float smoothNoise3D(float3 p) {
            float3 i = floor(p);
            float3 f = fract(p);
            float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

            float n000 = hash31(i + float3(0, 0, 0));
            float n100 = hash31(i + float3(1, 0, 0));
            float n010 = hash31(i + float3(0, 1, 0));
            float n110 = hash31(i + float3(1, 1, 0));
            float n001 = hash31(i + float3(0, 0, 1));
            float n101 = hash31(i + float3(1, 0, 1));
            float n011 = hash31(i + float3(0, 1, 1));
            float n111 = hash31(i + float3(1, 1, 1));

            return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
                       mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
        }

        inline float lunarFBM(float3 p) {
            float v = 0.0;
            float a = 0.52;
            for (int i = 0; i < 5; ++i) {
                v += a * smoothNoise3D(p);
                p = p * 2.15 + float3(4.3, 1.7, 8.9);
                a *= 0.48;
            }
            return v;
        }

        // 3D Spherical Lunar Albedo Surface (Basaltic Maria, Anorthosite Highlands, Impact Craters)
        inline float sampleLunarAlbedo(float3 N) {
            float lowFBM = lunarFBM(N * 3.2);
            float mariaShape = smoothstep(0.40, 0.58, lowFBM);
            float baseAlbedo = mix(0.28, 0.11, mariaShape);

            float detailNoise = lunarFBM(N * 14.0 + float3(11.2, 7.3, 3.1));
            baseAlbedo += (detailNoise - 0.5) * 0.06;

            float3 craterCenter1 = normalize(float3(0.35, -0.45, 0.82));
            float d1 = length(N - craterCenter1);
            float craterRim1 = smoothstep(0.12, 0.08, d1) * smoothstep(0.02, 0.07, d1);
            float craterRays1 = exp(-d1 * 4.5) * smoothstep(0.3, 0.7, smoothNoise3D(N * 25.0));

            float3 craterCenter2 = normalize(float3(-0.25, 0.35, 0.90));
            float d2 = length(N - craterCenter2);
            float craterRim2 = smoothstep(0.10, 0.06, d2) * smoothstep(0.015, 0.05, d2);

            baseAlbedo += (craterRim1 * 0.12 + craterRays1 * 0.09 + craterRim2 * 0.08);
            return saturate(baseAlbedo);
        }

        // Cornette-Shanks Atmospheric Mie Phase Function
        inline float cornetteShanksPhase(float cosTheta, float g) {
            float g2 = g * g;
            return (3.0 * (1.0 - g2) / (2.0 * (2.0 + g2))) * ((1.0 + cosTheta * cosTheta) / pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
        }

        // Lunar Regolith Lommel-Seeliger + Lambertian Hybrid Bidirectional Reflectance
        inline float lunarRegolithBRDF(float NdotL, float NdotV) {
            if (NdotL <= 0.0) return 0.0;
            float lommelSeeliger = NdotL / (NdotL + max(NdotV, 0.001));
            return mix(NdotL, lommelSeeliger, 0.70);
        }

        // Physically-Based Sun & 3D Spherical Moon Fragment Shader
        fragment half4 celestialAtmosphereFragment(
            VertexOut in [[stage_in]],
            constant CelestialAtmosphereUniforms &uniforms [[buffer(0)]]
        ) {
            float2 uv = in.uv;
            float aspect = uniforms.resolution.x / uniforms.resolution.y;

            // Isotropic Camera Coordinate Projection
            float2 p = (uv - float2(0.5, 0.5));
            p.x *= aspect;
            float fov = 1.0;
            float3 v = normalize(float3(p.x * fov, -p.y * fov, 1.0));

            float3 s = normalize(float3(uniforms.sunDir));
            float3 m = normalize(float3(uniforms.moonDir));

            float cosSun = dot(v, s);
            float angleSun = acos(clamp(cosSun, -1.0, 1.0));

            float cosMoon = dot(v, m);
            float angleMoon = acos(clamp(cosMoon, -1.0, 1.0));

            // ----------------------------------------------------
            // ☀️ 1. PHYSICAL SUN RENDERING (4 Distinct Optical Scales)
            // ----------------------------------------------------
            // Scale 1: Crisp Physical Sun Disk (~1.15° angular diameter)
            float sunAngularRadius = 0.020;

            // Atmospheric Extinction based on elevation (Bruneton model transmittance)
            float airMass = 1.0 / max(s.y + 0.05, 0.02);
            float3 rayleighBeta = float3(0.058, 0.135, 0.331);
            float3 sunTransmittance = exp(-rayleighBeta * (airMass * 0.40));

            float3 baseSunColor = float3(1.0, 0.99, 0.96);
            float3 attenuatedSunColor = baseSunColor * sunTransmittance * 1.5;

            float sunDisk = 0.0;
            if (angleSun <= sunAngularRadius) {
                float rNorm = angleSun / sunAngularRadius;
                float mu = sqrt(max(0.0, 1.0 - rNorm * rNorm));
                float limbDarkening = 0.55 + 0.45 * mu; // Solar limb darkening
                float edgeAA = smoothstep(sunAngularRadius, sunAngularRadius - 0.0012, angleSun);
                sunDisk = edgeAA * limbDarkening * 4.0;
            }

            // Scale 2: Optical Solar Corona Bloom (Compact, high-luminance forward flare)
            float corona = exp(-angleSun / 0.010) * 0.45;

            // Scale 3: Atmospheric Forward Mie Scattering (Controlled soft halo)
            float miePhase = cornetteShanksPhase(cosSun, 0.88);
            float mieHalo = miePhase * 0.005 * smoothstep(-0.1, 0.3, s.y);

            // ----------------------------------------------------
            // 🌙 2. PHYSICAL 3D SPHERICAL MOON RENDERING
            // ----------------------------------------------------
            // Moon angular radius (~1.60° diameter)
            float moonAngularRadius = 0.028;
            float3 moonPixel = float3(0.0);
            float moonAlpha = 0.0;

            if (angleMoon <= moonAngularRadius) {
                float3 upRef = float3(0.0, 1.0, 0.0);
                float3 moonRight = normalize(cross(m, upRef));
                float3 moonUp = cross(moonRight, m);

                float dRight = dot(v - m, moonRight);
                float dUp = dot(v - m, moonUp);
                float2 diskPos = float2(dRight, dUp) / moonAngularRadius;

                float diskDistSq = dot(diskPos, diskPos);
                if (diskDistSq <= 1.0) {
                    // Reconstruct 3D Spherical Surface Normal
                    float Nz = sqrt(1.0 - diskDistSq);
                    float3 N = normalize(moonRight * diskPos.x + moonUp * diskPos.y + m * Nz);

                    // True Geometric Illumination & Phase Terminator
                    float3 L = normalize(float3(uniforms.moonToSunDir));
                    float NdotL = dot(N, L);
                    float NdotV = dot(N, -v);

                    // Pure Dark Unlit Hemisphere: only illuminate sunlit surface (NdotL > 0)
                    if (NdotL > 0.0) {
                        float geomIllum = saturate(lunarRegolithBRDF(NdotL, NdotV));

                        // Surface Maria & Highlands Albedo
                        float albedo = sampleLunarAlbedo(N);

                        float3 sunlightColor = float3(0.96, 0.95, 0.92);
                        float3 litSurface = albedo * geomIllum * sunlightColor * 2.5;

                        // Anti-aliased limb and terminator transition
                        float terminatorAA = smoothstep(0.0, 0.025, NdotL);
                        float edgeAA = smoothstep(1.0, 0.94, sqrt(diskDistSq));
                        float combinedAlpha = edgeAA * terminatorAA;

                        moonPixel = litSurface * combinedAlpha;
                        moonAlpha = combinedAlpha;
                    }
                }
            }

            // Strictly Concentric Moon Atmospheric Scattering Glow (scaled with illumination)
            float moonMie = cornetteShanksPhase(cosMoon, 0.85);
            float moonIllumFraction = saturate(uniforms.moonToSunDir.z * 0.5 + 0.5);
            float moonHalo = (exp(-angleMoon / 0.040) * 0.06 + moonMie * 0.005) * (0.15 + 0.85 * moonIllumFraction);
            float3 moonAtmosphereColor = float3(0.55, 0.70, 0.95) * moonHalo;

            // ----------------------------------------------------
            // 🛠️ 3. DEBUG MODES & FINAL COMPOSITING
            // ----------------------------------------------------
            if (uniforms.debugMode == 1) {
                // SUN DISK ONLY
                return half4(half3(attenuatedSunColor * sunDisk), half(sunDisk > 0.01 ? 1.0 : 0.0));
            } else if (uniforms.debugMode == 2) {
                // SUN + ATMOSPHERE
                float3 sunAtmosphere = attenuatedSunColor * (sunDisk + corona + mieHalo);
                return half4(half3(sunAtmosphere), half(saturate(sunDisk + corona * 0.7 + mieHalo * 0.5)));
            } else if (uniforms.debugMode == 3) {
                // MOON DISK ONLY
                return half4(half3(moonPixel), half(moonAlpha));
            } else if (uniforms.debugMode == 4) {
                // MOON SURFACE + PHASE
                return half4(half3(moonPixel), half(moonAlpha));
            } else if (uniforms.debugMode == 5) {
                // MOON + ATMOSPHERE
                float3 moonComp = moonPixel + moonAtmosphereColor;
                return half4(half3(moonComp), half(saturate(moonAlpha + moonHalo * 0.8)));
            }

            // Normal Composite Mode
            if (uniforms.isNight > 0.5) {
                float3 totalMoon = moonPixel + moonAtmosphereColor;
                float totalAlpha = saturate(moonAlpha + moonHalo * 0.75);
                return half4(half3(totalMoon), half(totalAlpha));
            } else {
                float3 totalSun = attenuatedSunColor * (sunDisk + corona + mieHalo);
                float totalAlpha = saturate(sunDisk + corona * 0.75 + mieHalo * 0.45);
                return half4(half3(totalSun), half(totalAlpha));
            }
        }
        """

        do {
            let library = try device.makeLibrary(source: mslSource, options: nil)
            let pipeDesc = MTLRenderPipelineDescriptor()
            pipeDesc.vertexFunction = library.makeFunction(name: "celestialVertex")
            pipeDesc.fragmentFunction = library.makeFunction(name: "celestialAtmosphereFragment")
            pipeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeDesc.colorAttachments[0].isBlendingEnabled = true
            pipeDesc.colorAttachments[0].sourceRGBBlendFactor = .one
            pipeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipeDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipeDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipeDesc)
            self.isInitialized = true
        } catch {
            print("CelestialAtmosphereEngine failed to initialize: \(error)")
        }
    }

    /// Helper to convert normalized 2D Screen UV to Isotropic 3D View Ray Direction
    public static func rayDirection(for uv: CGPoint, aspect: Float) -> (Float, Float, Float) {
        let pX = Float(uv.x - 0.5) * aspect
        let pY = -Float(uv.y - 0.5)
        let len = sqrt(pX * pX + pY * pY + 1.0)
        return (pX / len, pY / len, 1.0 / len)
    }
}

// MARK: - SwiftUI Metal Celestial Atmosphere View

public struct CelestialAtmosphereView: UIViewRepresentable {
    public var isNight: Bool
    public var sunDir: (Float, Float, Float)
    public var moonDir: (Float, Float, Float)
    public var moonToSunDir: (Float, Float, Float)
    public var moonPhase: Float
    public var debugMode: CelestialAtmosphereDebugMode

    public init(
        isNight: Bool = false,
        sunDir: (Float, Float, Float)? = nil,
        moonDir: (Float, Float, Float)? = nil,
        moonToSunDir: (Float, Float, Float)? = nil,
        moonPhase: Float? = nil,
        debugMode: CelestialAtmosphereDebugMode = .composite
    ) {
        self.isNight = isNight
        let aspect: Float = 1170.0 / 2532.0
        self.sunDir = sunDir ?? CelestialAtmosphereEngine.rayDirection(for: CGPoint(x: 0.32, y: 0.18), aspect: aspect)
        self.moonDir = moonDir ?? CelestialAtmosphereEngine.rayDirection(for: CGPoint(x: 0.70, y: 0.20), aspect: aspect)
        self.moonToSunDir = moonToSunDir ?? LunarPhaseEngine.moonToSunDirection()
        self.moonPhase = moonPhase ?? Float(LunarPhaseEngine.phase())
        self.debugMode = debugMode
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = CelestialAtmosphereEngine.shared.device
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
        context.coordinator.isNight = isNight
        context.coordinator.sunDir = sunDir
        context.coordinator.moonDir = moonDir
        context.coordinator.moonToSunDir = moonToSunDir
        context.coordinator.moonPhase = moonPhase
        context.coordinator.debugMode = debugMode
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            isNight: isNight,
            sunDir: sunDir,
            moonDir: moonDir,
            moonToSunDir: moonToSunDir,
            moonPhase: moonPhase,
            debugMode: debugMode
        )
    }

    public final class Coordinator: NSObject, MTKViewDelegate {
        var isNight: Bool
        var sunDir: (Float, Float, Float)
        var moonDir: (Float, Float, Float)
        var moonToSunDir: (Float, Float, Float)
        var moonPhase: Float
        var debugMode: CelestialAtmosphereDebugMode
        private let startTime = Date.timeIntervalSinceReferenceDate

        init(
            isNight: Bool,
            sunDir: (Float, Float, Float),
            moonDir: (Float, Float, Float),
            moonToSunDir: (Float, Float, Float),
            moonPhase: Float,
            debugMode: CelestialAtmosphereDebugMode
        ) {
            self.isNight = isNight
            self.sunDir = sunDir
            self.moonDir = moonDir
            self.moonToSunDir = moonToSunDir
            self.moonPhase = moonPhase
            self.debugMode = debugMode
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            let width = Float(view.drawableSize.width)
            let height = Float(view.drawableSize.height)
            guard width > 0, height > 0 else { return }

            let engine = MainActor.assumeIsolated({ CelestialAtmosphereEngine.shared })
            guard let queue = engine.commandQueue,
                  let pipeline = engine.pipelineState,
                  let drawable = view.currentDrawable,
                  let renderPass = view.currentRenderPassDescriptor else {
                return
            }

            let elapsed = Float(Date.timeIntervalSinceReferenceDate - startTime)

            var uniforms = CelestialAtmosphereUniforms(
                resolution: (width, height),
                time: elapsed,
                sunElevation: sunDir.1,
                sunDir: sunDir,
                moonDir: moonDir,
                moonToSunDir: moonToSunDir,
                moonPhase: moonPhase,
                debugMode: debugMode,
                isNight: isNight
            )

            guard let cmdBuffer = queue.makeCommandBuffer(),
                  let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
                return
            }

            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<CelestialAtmosphereUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
    }
}
