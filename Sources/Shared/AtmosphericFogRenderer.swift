import SwiftUI
import Metal
import MetalKit

// MARK: - Atmospheric Fog Mode

public enum AtmosphericFogMode: Int32, Sendable {
    case fog = 0   // Nebbia: Dense atmospheric volume, low visibility, deep ground scattering
    case haze = 1  // Foschia: Light atmospheric veil, high transparency, subtle depth extinction
}

// MARK: - Metal Atmospheric Fog Uniforms

public struct AtmosphericFogUniforms {
    public var resolution: (Float, Float)
    public var time: Float
    public var isHaze: Int32
    public var baseDensity: Float
    public var verticalFalloff: Float
    public var scatteringFactor: Float
    public var ambientR: Float
    public var ambientG: Float
    public var ambientB: Float
    public var pad0: Float = 0
    public var pad1: Float = 0
    public var pad2: Float = 0

    public init(
        resolution: (Float, Float) = (1170, 2532),
        time: Float = 0.0,
        isHaze: AtmosphericFogMode = .fog,
        baseDensity: Float = 0.85,
        verticalFalloff: Float = 1.0,
        scatteringFactor: Float = 1.4,
        ambientColor: (Float, Float, Float) = (0.88, 0.91, 0.96)
    ) {
        self.resolution = resolution
        self.time = time
        self.isHaze = isHaze.rawValue
        self.baseDensity = baseDensity
        self.verticalFalloff = verticalFalloff
        self.scatteringFactor = scatteringFactor
        self.ambientR = ambientColor.0
        self.ambientG = ambientColor.1
        self.ambientB = ambientColor.2
    }
}

// MARK: - Metal Atmospheric Fog Engine

@MainActor
public final class AtmosphericFogEngine {
    public static let shared = AtmosphericFogEngine()

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

        struct FullscreenVertexOut {
            float4 position [[position]];
            float2 uv;
        };

        struct AtmosphericFogUniforms {
            float2 resolution;
            float time;
            int isHaze;
            float baseDensity;
            float verticalFalloff;
            float scatteringFactor;
            float ambientR;
            float ambientG;
            float ambientB;
            float pad0;
            float pad1;
            float pad2;
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

        vertex FullscreenVertexOut atmosphericFogVertex(uint vertexID [[vertex_id]]) {
            FullscreenVertexOut out;
            float2 grid = float2((vertexID << 1) & 2, vertexID & 2);
            out.position = float4(grid * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
            out.uv = grid;
            return out;
        }

        // 🌫️ Continuous Atmospheric Volumetric Fog / Mist Fullscreen Shader (ZERO geometric bands/layers)
        fragment half4 atmosphericFogFragment(
            FullscreenVertexOut in [[stage_in]],
            constant AtmosphericFogUniforms &uniforms [[buffer(0)]]
        ) {
            float2 uv = in.uv;
            float aspect = uniforms.resolution.x / uniforms.resolution.y;

            // 1. Ultra-slow Horizontal Advection (imperceptible drift, zero wave oscillations)
            float time = uniforms.time;
            float advectionX = time * 0.012;

            // 2. Continuous Height Fog Vertical Profile (Smooth gradient without abrupt thresholds)
            // Higher density near the bottom/horizon, naturally thinning upwards into the sky
            float heightProfile;
            if (uniforms.isHaze == 1) {
                // Foschia: soft uniform atmospheric haze with gentle vertical thinning
                heightProfile = pow(clamp(uv.y * 1.15 - 0.05, 0.0, 1.0), 1.1);
            } else {
                // Nebbia: deep ground immersion rising softly to upper atmosphere
                heightProfile = pow(clamp(uv.y * 1.08 - 0.04, 0.0, 1.0), 0.75);
            }

            // 3. Very Low-Frequency Procedural Atmospheric FBM (Macro scale, zero sharp contours)
            float2 sampleCoord = float2(uv.x * aspect * 1.2 + advectionX, uv.y * 0.9);

            // Subtle Domain Warping
            float warpX = smoothNoise2D(sampleCoord * 1.5 + float2(time * 0.008, 0.0));
            float warpY = smoothNoise2D(sampleCoord * 1.5 + float2(0.0, time * 0.006));
            float2 warpedCoord = sampleCoord + float2(warpX - 0.5, warpY - 0.5) * 0.28;

            float fbmNoise = macroFBM(warpedCoord * 1.4);

            // 4. Density Field
            float density;
            if (uniforms.isHaze == 1) {
                // Foschia: light veil
                density = (0.22 + fbmNoise * 0.18) * heightProfile * uniforms.baseDensity;
            } else {
                // Nebbia: thick diffuse atmospheric volume
                density = (0.46 + fbmNoise * 0.32) * heightProfile * uniforms.baseDensity;
            }

            density = clamp(density, 0.0, 0.90);

            if (density <= 0.002) {
                return half4(0.0);
            }

            // 5. Atmospheric Rayleigh & Mie scattering ambient color (exact RGB components)
            half3 fogColor = half3(uniforms.ambientR, uniforms.ambientG, uniforms.ambientB);

            // Alpha blending: soft exponential extinction (Beer-Lambert law approximation)
            float extinction = 1.0 - exp(-density * uniforms.scatteringFactor);

            return half4(fogColor * half(extinction), half(extinction));
        }
        """

        do {
            let library = try device.makeLibrary(source: mslSource, options: nil)
            let pipelineDesc = MTLRenderPipelineDescriptor()
            pipelineDesc.vertexFunction = library.makeFunction(name: "atmosphericFogVertex")
            pipelineDesc.fragmentFunction = library.makeFunction(name: "atmosphericFogFragment")
            pipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDesc.colorAttachments[0].isBlendingEnabled = true
            pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDesc)
            self.isInitialized = true
        } catch {
            print("AtmosphericFogEngine failed to compile shaders: \(error)")
        }
    }
}

// MARK: - SwiftUI Atmospheric Fog View

public struct AtmosphericFogView: UIViewRepresentable {
    public var mode: AtmosphericFogMode
    public var baseDensity: Float
    public var scatteringFactor: Float
    public var ambientColor: (Float, Float, Float)

    public init(
        mode: AtmosphericFogMode = .fog,
        baseDensity: Float = 0.85,
        scatteringFactor: Float = 1.4,
        ambientColor: (Float, Float, Float) = (0.88, 0.91, 0.96)
    ) {
        self.mode = mode
        self.baseDensity = baseDensity
        self.scatteringFactor = scatteringFactor
        self.ambientColor = ambientColor
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = AtmosphericFogEngine.shared.device
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
        context.coordinator.mode = mode
        context.coordinator.baseDensity = baseDensity
        context.coordinator.scatteringFactor = scatteringFactor
        context.coordinator.ambientColor = ambientColor
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            mode: mode,
            baseDensity: baseDensity,
            scatteringFactor: scatteringFactor,
            ambientColor: ambientColor
        )
    }

    public final class Coordinator: NSObject, MTKViewDelegate {
        var mode: AtmosphericFogMode
        var baseDensity: Float
        var scatteringFactor: Float
        var ambientColor: (Float, Float, Float)
        private let startTime = Date.timeIntervalSinceReferenceDate

        init(
            mode: AtmosphericFogMode,
            baseDensity: Float,
            scatteringFactor: Float,
            ambientColor: (Float, Float, Float)
        ) {
            self.mode = mode
            self.baseDensity = baseDensity
            self.scatteringFactor = scatteringFactor
            self.ambientColor = ambientColor
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            let width = Float(view.drawableSize.width)
            let height = Float(view.drawableSize.height)
            guard width > 0, height > 0 else { return }

            let engine = MainActor.assumeIsolated({ AtmosphericFogEngine.shared })
            guard let queue = engine.commandQueue,
                  let pipeline = engine.pipelineState,
                  let drawable = view.currentDrawable,
                  let renderPass = view.currentRenderPassDescriptor else {
                return
            }

            let elapsed = Float(Date.timeIntervalSinceReferenceDate - startTime)

            var uniforms = AtmosphericFogUniforms(
                resolution: (width, height),
                time: elapsed,
                isHaze: mode,
                baseDensity: baseDensity,
                verticalFalloff: 1.0,
                scatteringFactor: scatteringFactor,
                ambientColor: ambientColor
            )

            guard let cmdBuffer = queue.makeCommandBuffer(),
                  let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
                return
            }

            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<AtmosphericFogUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
    }
}
