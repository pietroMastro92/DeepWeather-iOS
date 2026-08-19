import SwiftUI
import Metal
import MetalKit

// MARK: - Metal Volumetric Cloud Uniforms

struct VolumetricCloudUniforms {
    var resolution: (Float, Float)
    var time: Float
    var coverage: Float
    var sunDir: (Float, Float, Float)
    var isNight: Float
    var isOvercast: Float
    var cloudType: Float
    var padding: Float = 0
}

// MARK: - Metal Volumetric Cloud Engine (3D Pre-Generated Noise Textures + Hardware Trilinear Sampling)

@MainActor
public final class VolumetricCloudEngine {
    public static let shared = VolumetricCloudEngine()

    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    private(set) var renderPipelineState: MTLRenderPipelineState?
    private(set) var shapeNoiseTexture: MTLTexture?
    private(set) var detailNoiseTexture: MTLTexture?
    private(set) var samplerState: MTLSamplerState?
    private(set) var isInitialized: Bool = false

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
        guard let device = device, let queue = commandQueue else { return }

        let mslSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct CloudUniforms {
            float2 resolution;
            float time;
            float coverage;
            float3 sunDir;
            float isNight;
            float isOvercast;
            float cloudType;
            float padding;
        };

        struct VertexOut {
            float4 position [[position]];
            float2 uv;
        };

        // Mathematical Positive Modulo for Continuous Seamless Periodicity
        inline float pMod(float a, float b) {
            return a - b * floor(a / b);
        }

        inline float3 pMod3(float3 a, float b) {
            return a - b * floor(a / b);
        }

        // 3D Periodic Hash for Seamless Tiling
        inline float3 hash33Period(float3 p, float period) {
            p = pMod3(p, period);
            p = fract(p * float3(0.1031, 0.1030, 0.0973));
            p += dot(p, p.yxz + 33.33);
            return fract((p.xxy + p.yxx) * p.zyx);
        }

        // 3D Periodic Gradient Noise with C2-Continuous Quintic Smoothstep
        inline float gradNoise3DPeriod(float3 p, float period) {
            float3 i = floor(p);
            float3 f = fract(p);
            float3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

            float n000 = dot(hash33Period(i + float3(0.0, 0.0, 0.0), period) * 2.0 - 1.0, f - float3(0.0, 0.0, 0.0));
            float n100 = dot(hash33Period(i + float3(1.0, 0.0, 0.0), period) * 2.0 - 1.0, f - float3(1.0, 0.0, 0.0));
            float n010 = dot(hash33Period(i + float3(0.0, 1.0, 0.0), period) * 2.0 - 1.0, f - float3(0.0, 1.0, 0.0));
            float n110 = dot(hash33Period(i + float3(1.0, 1.0, 0.0), period) * 2.0 - 1.0, f - float3(1.0, 1.0, 0.0));
            float n001 = dot(hash33Period(i + float3(0.0, 0.0, 1.0), period) * 2.0 - 1.0, f - float3(0.0, 0.0, 1.0));
            float n101 = dot(hash33Period(i + float3(1.0, 0.0, 1.0), period) * 2.0 - 1.0, f - float3(1.0, 0.0, 1.0));
            float n011 = dot(hash33Period(i + float3(0.0, 1.0, 1.0), period) * 2.0 - 1.0, f - float3(0.0, 1.0, 1.0));
            float n111 = dot(hash33Period(i + float3(1.0, 1.0, 1.0), period) * 2.0 - 1.0, f - float3(1.0, 1.0, 1.0));

            float v = mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
                          mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
            return v * 0.5 + 0.5;
        }

        // 3D Periodic Worley Cellular Noise
        inline float worley3DPeriod(float3 p, float period) {
            float3 id = floor(p);
            float3 fd = fract(p);
            float minDist = 1.0;

            for (int z = -1; z <= 1; ++z) {
                for (int y = -1; y <= 1; ++y) {
                    for (int x = -1; x <= 1; ++x) {
                        float3 offset = float3(float(x), float(y), float(z));
                        float3 cell = id + offset;
                        float3 h = hash33Period(cell, period);
                        float3 pos = offset + h;
                        float d = length(fd - pos);
                        minDist = min(minDist, d);
                    }
                }
            }
            return minDist;
        }

        // Compute Kernel: Pre-generate Shape Noise 3D Texture (64x64x32)
        kernel void generateShapeNoise(
            texture3d<float, access::write> outTex [[texture(0)]],
            uint3 gid [[thread_position_in_grid]]
        ) {
            float3 size = float3(outTex.get_width(), outTex.get_height(), outTex.get_depth());
            float3 uvw = float3(gid) / size;

            float p1 = gradNoise3DPeriod(uvw * 4.0, 4.0);
            float p2 = gradNoise3DPeriod(uvw * 8.0, 8.0) * 0.5;
            float p3 = gradNoise3DPeriod(uvw * 16.0, 16.0) * 0.25;
            float perlin = (p1 + p2 + p3) / 1.75;

            float w1 = worley3DPeriod(uvw * 4.0, 4.0);
            float w2 = worley3DPeriod(uvw * 8.0, 8.0);
            float warpNoise = gradNoise3DPeriod(uvw * 4.0 + float3(17.3, 31.7, 53.1), 4.0);

            float perlinWorley = mix(1.0 - w1, perlin, 0.65);
            outTex.write(float4(perlinWorley, 1.0 - w1, 1.0 - w2, warpNoise), gid);
        }

        // Compute Kernel: Pre-generate Detail Erosion 3D Texture (32x32x32)
        kernel void generateDetailNoise(
            texture3d<float, access::write> outTex [[texture(0)]],
            uint3 gid [[thread_position_in_grid]]
        ) {
            float3 size = float3(outTex.get_width(), outTex.get_height(), outTex.get_depth());
            float3 uvw = float3(gid) / size;

            float w1 = worley3DPeriod(uvw * 4.0, 4.0);
            float w2 = worley3DPeriod(uvw * 8.0, 8.0);
            float w3 = worley3DPeriod(uvw * 16.0, 16.0);
            float detail = (1.0 - w1) * 0.62 + (1.0 - w2) * 0.28 + (1.0 - w3) * 0.10;

            outTex.write(float4(detail, 0.0, 0.0, 1.0), gid);
        }

        // Fullscreen Triangle Vertex Shader
        vertex VertexOut volumetricCloudVertex(uint vertexID [[vertex_id]]) {
            VertexOut out;
            float2 grid = float2((vertexID << 1) & 2, vertexID & 2);
            out.position = float4(grid * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
            out.uv = grid;
            return out;
        }

        inline float bayer4x4(float2 pos) {
            int2 p = int2(pos) & 3;
            const float m[16] = {
                0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
               12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
                3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
               15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
            };
            return m[p.y * 4 + p.x];
        }

        inline float hgPhase(float cosTheta, float g) {
            float g2 = g * g;
            return (1.0 - g2) / (4.0 * 3.14159265 * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
        }

        inline bool raySphereIntersect(float3 ro, float3 rd, float radius, thread float &t) {
            float b = dot(ro, rd);
            float c = dot(ro, ro) - radius * radius;
            float disc = b * b - c;
            if (disc < 0.0) return false;
            float s = sqrt(disc);
            t = -b + s;
            return t > 0.0;
        }

        // ☁️ Procedural 3D Cloud Density Function (Dynamic Drifting & Organic Evolution Across Full Sky)
        inline float sampleCloudDensity(
            float3 p, float h, float time, float coverage, float isOvercast, float cloudType,
            texture3d<float> shapeTex, texture3d<float> detailTex, sampler s
        ) {
            if (h < 0.0 || h > 1.0) return 0.0;

            float heightProfile;
            if (cloudType > 0.5) {
                heightProfile = smoothstep(0.0, 0.02, h) * smoothstep(0.55, 0.10, h);
            } else if (isOvercast > 0.5) {
                heightProfile = smoothstep(0.0, 0.08, h) * smoothstep(1.0, 0.85, h);
            } else {
                heightProfile = smoothstep(0.0, 0.16, h) * smoothstep(1.0, 0.68, h) * (1.0 + 0.25 * sin(h * 3.14159));
            }

            // Continuous dynamic wind advection across the entire sky
            float3 wind = float3(time * 0.012, 0.0, time * 0.006);
            float3 uvw = (p + float3(500.0, 500.0, 500.0)) * 0.065 + wind;

            float warp = (shapeTex.sample(s, uvw).a - 0.5) * 0.035;
            float3 warpedUVW = uvw + float3(warp, warp * 0.5, -warp);

            float4 shape = shapeTex.sample(s, warpedUVW);
            float baseFBM = shape.r * 0.62 + shape.g * 0.26 + shape.b * 0.12;

            float threshold = cloudType > 0.5 ? 0.28 : (isOvercast > 0.5 ? 0.32 : (0.75 - coverage * 0.52));
            float baseDensity = (baseFBM - threshold) * heightProfile;

            if (baseDensity <= 0.002) return 0.0;

            baseDensity *= (cloudType > 0.5 ? 2.2 : 1.8);

            float3 detailUVW = warpedUVW * 3.2 - float3(time * 0.010, 0, 0);
            float detail = detailTex.sample(s, detailUVW).r;
            float eroded = baseDensity - (1.0 - detail) * 0.20 * (1.0 - h * 0.45);

            return max(0.0f, eroded * 2.0f);
        }

        inline float sampleCoarseDensity(
            float3 p, float h, float time, float coverage, float isOvercast, float cloudType,
            texture3d<float> shapeTex, sampler s
        ) {
            if (h < 0.0 || h > 1.0) return 0.0;
            float heightProfile = (cloudType > 0.5) ?
                (smoothstep(0.0, 0.02, h) * smoothstep(0.55, 0.10, h)) :
                ((isOvercast > 0.5) ?
                    (smoothstep(0.0, 0.08, h) * smoothstep(1.0, 0.85, h)) :
                    (smoothstep(0.0, 0.16, h) * smoothstep(1.0, 0.68, h)));
            float3 wind = float3(time * 0.012, 0.0, time * 0.006);
            float3 uvw = (p + float3(500.0, 500.0, 500.0)) * 0.065 + wind;
            float baseShape = shapeTex.sample(s, uvw).r;
            float threshold = cloudType > 0.5 ? 0.30 : (isOvercast > 0.5 ? 0.34 : (0.75 - coverage * 0.52));
            float baseDensity = (baseShape - threshold) * heightProfile;
            return max(0.0f, baseDensity * 1.6f);
        }

        // Hardware Trilinear Sampling Fragment Shader (Full Condition-Specific Atmospheric Photometry)
        fragment half4 volumetricCloudFragment(
            VertexOut in [[stage_in]],
            constant CloudUniforms &uniforms [[buffer(0)]],
            texture3d<float> shapeTex [[texture(0)]],
            texture3d<float> detailTex [[texture(1)]],
            sampler s [[sampler(0)]]
        ) {
            float2 uv = in.uv;
            float aspect = uniforms.resolution.x / uniforms.resolution.y;

            float earthRadius = 140.0;
            float cloudAltMin = 2.0;
            float cloudAltMax = 5.5;
            float rBottom = earthRadius + cloudAltMin;
            float rTop = earthRadius + cloudAltMax;

            float3 ro = float3(0.0, earthRadius, 0.0);

            float pitch = (1.0 - uv.y) * 1.30 + 0.22;
            float yaw = (uv.x - 0.5) * aspect * 1.20;
            float3 rd = normalize(float3(yaw, pitch, 1.0));

            float tNear = 0.0;
            float tFar = 0.0;

            if (!raySphereIntersect(ro, rd, rBottom, tNear) || !raySphereIntersect(ro, rd, rTop, tFar)) {
                return half4(0.0);
            }

            tNear = max(0.0f, tNear);
            tFar = min(tFar, tNear + 30.0f);

            if (tNear >= tFar) {
                return half4(0.0);
            }

            const int steps = 24;
            float dt = (tFar - tNear) / float(steps);
            float dither = bayer4x4(in.position.xy) * dt;
            float t = tNear + dither;

            float T = 1.0;
            half3 accumColor = half3(0.0);

            float3 sunDir = normalize(uniforms.sunDir);
            float cosTheta = dot(rd, sunDir);
            float phase = 0.75 * hgPhase(cosTheta, 0.72) + 0.25 * hgPhase(cosTheta, -0.22);

            // Weather-Specific Photometric Lighting Profiles:
            half3 sunColor;
            half3 ambientBottom;
            half3 ambientTop;
            float sunIntensity;
            float ambientIntensity;
            float multiScatterPower;
            float extinctionRate;

            if (uniforms.isNight > 0.5) {
                // 🌙 NIGHT: Subtle nocturnal cloud silhouetting with soft silver lunar rim
                sunColor = half3(0.40, 0.50, 0.68);
                ambientBottom = half3(0.02, 0.04, 0.09);
                ambientTop = half3(0.07, 0.11, 0.18);
                sunIntensity = 0.45;
                ambientIntensity = 0.42;
                multiScatterPower = 0.20;
                extinctionRate = 1.45;
            } else if (uniforms.isOvercast > 0.5) {
                if (uniforms.coverage >= 0.82) {
                    // ⛈️ STORM / HEAVY RAIN: Dark, heavy, ominous overcast underbelly (Restored previous dark look)
                    sunColor = half3(0.48, 0.50, 0.54);
                    ambientBottom = half3(0.14, 0.16, 0.20);
                    ambientTop = half3(0.38, 0.42, 0.48);
                    sunIntensity = 0.90;
                    ambientIntensity = 0.65;
                    multiScatterPower = 0.15;
                    extinctionRate = 1.8;
                } else {
                    // ❄️ SNOW / WINTER OVERCAST: Cool winter slate gray
                    sunColor = half3(0.82, 0.86, 0.90);
                    ambientBottom = half3(0.38, 0.44, 0.50);
                    ambientTop = half3(0.75, 0.80, 0.85);
                    sunIntensity = 1.4;
                    ambientIntensity = 0.80;
                    multiScatterPower = 0.30;
                    extinctionRate = 1.5;
                }
            } else {
                // ☀️ SUNNY / PARTLY CLOUDY: Natural cumulus with soft ambient base and moderate solar highlights (Dimmer than solar disk)
                sunColor = half3(0.96, 0.94, 0.90);
                ambientBottom = half3(0.36, 0.44, 0.54);
                ambientTop = half3(0.62, 0.68, 0.76);
                sunIntensity = 0.85;
                ambientIntensity = 0.58;
                multiScatterPower = 0.32;
                extinctionRate = 1.35;
            }

            float horizonFactor = smoothstep(0.14, 0.42, rd.y);

            for (int i = 0; i < steps; ++i) {
                float3 p = ro + rd * t;
                float h = saturate((length(p) - rBottom) / (rTop - rBottom));
                float d = sampleCloudDensity(p, h, uniforms.time, uniforms.coverage, uniforms.isOvercast, uniforms.cloudType, shapeTex, detailTex, s);
                d *= (0.45 + 0.55 * horizonFactor);

                if (d > 0.005) {
                    float shadowOptDepth = 0.0;
                    float lStep = 0.32;
                    for (int k = 1; k <= 2; ++k) {
                        float3 lPos = p + sunDir * (float(k) * lStep);
                        float lh = saturate((length(lPos) - rBottom) / (rTop - rBottom));
                        shadowOptDepth += sampleCoarseDensity(lPos, lh, uniforms.time, uniforms.coverage, uniforms.isOvercast, uniforms.cloudType, shapeTex, s) * lStep;
                    }

                    float directTransmittance = exp(-shadowOptDepth * 1.10);
                    float multiScatterTransmittance = exp(-shadowOptDepth * 0.22) * multiScatterPower;
                    float powder = 1.0 - exp(-d * 2.0);

                    float sunScattering = (directTransmittance + multiScatterTransmittance) * mix(powder, 1.0, 0.35) * phase;

                    half3 ambient = mix(ambientBottom, ambientTop, half(h));
                    
                    float stepAlpha = 1.0 - exp(-d * dt * extinctionRate);
                    half3 radiance = (sunColor * half(sunScattering * sunIntensity) + ambient * half(ambientIntensity));
                    accumColor += radiance * half(T * stepAlpha);
                    T *= (1.0 - stepAlpha);

                    if (T < 0.02) break;
                }

                t += dt;
                if (t >= tFar) break;
            }

            half alpha = half(saturate(1.0 - T));
            return half4(accumColor, alpha);
        }
        """

        do {
            let library = try device.makeLibrary(source: mslSource, options: nil)

            // 1. Create and Generate 3D Noise Textures
            let shapeDesc = MTLTextureDescriptor()
            shapeDesc.textureType = .type3D
            shapeDesc.pixelFormat = .rgba8Unorm
            shapeDesc.width = 64
            shapeDesc.height = 64
            shapeDesc.depth = 32
            shapeDesc.usage = [.shaderWrite, .shaderRead]
            shapeDesc.storageMode = .shared
            let shapeTex = device.makeTexture(descriptor: shapeDesc)

            let detailDesc = MTLTextureDescriptor()
            detailDesc.textureType = .type3D
            detailDesc.pixelFormat = .r8Unorm
            detailDesc.width = 32
            detailDesc.height = 32
            detailDesc.depth = 32
            detailDesc.usage = [.shaderWrite, .shaderRead]
            detailDesc.storageMode = .shared
            let detailTex = device.makeTexture(descriptor: detailDesc)

            if let shapeTex = shapeTex,
               let detailTex = detailTex,
               let shapeFunc = library.makeFunction(name: "generateShapeNoise"),
               let detailFunc = library.makeFunction(name: "generateDetailNoise") {
                let shapePipeline = try device.makeComputePipelineState(function: shapeFunc)
                let detailPipeline = try device.makeComputePipelineState(function: detailFunc)

                if let cmd = queue.makeCommandBuffer(),
                   let enc = cmd.makeComputeCommandEncoder() {
                    enc.setComputePipelineState(shapePipeline)
                    enc.setTexture(shapeTex, index: 0)
                    enc.dispatchThreads(MTLSize(width: 64, height: 64, depth: 32), threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))

                    enc.setComputePipelineState(detailPipeline)
                    enc.setTexture(detailTex, index: 0)
                    enc.dispatchThreads(MTLSize(width: 32, height: 32, depth: 32), threadsPerThreadgroup: MTLSize(width: 4, height: 4, depth: 4))

                    enc.endEncoding()
                    cmd.commit()
                    cmd.waitUntilCompleted()
                }

                self.shapeNoiseTexture = shapeTex
                self.detailNoiseTexture = detailTex
            }

            // 2. Linear Trilinear Sampler
            let sampDesc = MTLSamplerDescriptor()
            sampDesc.sAddressMode = .repeat
            sampDesc.tAddressMode = .repeat
            sampDesc.rAddressMode = .repeat
            sampDesc.minFilter = .linear
            sampDesc.magFilter = .linear
            sampDesc.mipFilter = .linear
            self.samplerState = device.makeSamplerState(descriptor: sampDesc)

            // 3. Render Pipeline
            let pipeDesc = MTLRenderPipelineDescriptor()
            pipeDesc.vertexFunction = library.makeFunction(name: "volumetricCloudVertex")
            pipeDesc.fragmentFunction = library.makeFunction(name: "volumetricCloudFragment")
            pipeDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipeDesc.colorAttachments[0].isBlendingEnabled = true
            pipeDesc.colorAttachments[0].sourceRGBBlendFactor = .one
            pipeDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipeDesc.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipeDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipeDesc)
            self.isInitialized = true
        } catch {
            print("VolumetricCloudEngine failed to initialize: \(error)")
        }
    }
}

// MARK: - SwiftUI Metal Volumetric Clouds View

public struct VolumetricCloudsView: UIViewRepresentable {
    public var coverage: Float
    public var sunDir: (Float, Float, Float)
    public var isNight: Bool
    public var isOvercast: Bool
    public var cloudType: Float
    public var timeScale: Float

    public init(
        coverage: Float = 0.48,
        sunDir: (Float, Float, Float) = (0.35, 0.75, 0.45),
        isNight: Bool = false,
        isOvercast: Bool = false,
        cloudType: Float = 0.0,
        timeScale: Float = 1.0
    ) {
        self.coverage = coverage
        self.sunDir = sunDir
        self.isNight = isNight
        self.isOvercast = isOvercast
        self.cloudType = cloudType
        self.timeScale = timeScale
    }

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = VolumetricCloudEngine.shared.device
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
        context.coordinator.coverage = coverage
        context.coordinator.sunDir = sunDir
        context.coordinator.isNight = isNight
        context.coordinator.isOvercast = isOvercast
        context.coordinator.cloudType = cloudType
        context.coordinator.timeScale = timeScale
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            coverage: coverage,
            sunDir: sunDir,
            isNight: isNight,
            isOvercast: isOvercast,
            cloudType: cloudType,
            timeScale: timeScale
        )
    }

    public final class Coordinator: NSObject, MTKViewDelegate {
        var coverage: Float
        var sunDir: (Float, Float, Float)
        var isNight: Bool
        var isOvercast: Bool
        var cloudType: Float
        var timeScale: Float
        private let startTime = Date.timeIntervalSinceReferenceDate

        init(
            coverage: Float,
            sunDir: (Float, Float, Float),
            isNight: Bool,
            isOvercast: Bool,
            cloudType: Float,
            timeScale: Float
        ) {
            self.coverage = coverage
            self.sunDir = sunDir
            self.isNight = isNight
            self.isOvercast = isOvercast
            self.cloudType = cloudType
            self.timeScale = timeScale
        }

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        public func draw(in view: MTKView) {
            let width = Float(view.drawableSize.width)
            let height = Float(view.drawableSize.height)
            guard width > 0, height > 0 else { return }

            let engine = MainActor.assumeIsolated({ VolumetricCloudEngine.shared })
            guard let queue = engine.commandQueue,
                  let pipeline = engine.renderPipelineState,
                  let shapeTex = engine.shapeNoiseTexture,
                  let detailTex = engine.detailNoiseTexture,
                  let sampler = engine.samplerState,
                  let drawable = view.currentDrawable,
                  let renderPass = view.currentRenderPassDescriptor else {
                return
            }

            let elapsed = Float(Date.timeIntervalSinceReferenceDate - startTime) * timeScale

            var uniforms = VolumetricCloudUniforms(
                resolution: (width, height),
                time: elapsed,
                coverage: coverage,
                sunDir: sunDir,
                isNight: isNight ? 1.0 : 0.0,
                isOvercast: isOvercast ? 1.0 : 0.0,
                cloudType: cloudType
            )

            guard let cmdBuffer = queue.makeCommandBuffer(),
                  let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
                return
            }

            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<VolumetricCloudUniforms>.stride, index: 0)
            encoder.setFragmentTexture(shapeTex, index: 0)
            encoder.setFragmentTexture(detailTex, index: 1)
            encoder.setFragmentSamplerState(sampler, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
    }
}
