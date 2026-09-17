// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import MetalKit
import QuartzCore
import GalleryUI
import StateUIAppKit

/// A cube turning on the GPU - an ordinary `MTKView` that knows nothing of
/// StateUI.
///
/// `register()`, at the end of this file, adds it for `MetalCubeContract`, and
/// that registration is the whole bridge. The Swift half is
/// Sources/Samples/Interop/MetalCube.swift.
///
/// Its shaders are compiled FROM SOURCE as the view is made, so the
/// application ships no `.metal` file and its build needs nothing added to it.
///
/// It renders in `draw(_:)` rather than through an `MTKViewDelegate`: a view
/// that draws itself needs no second object, and this way the drawing runs
/// where every other `NSView` draws.
final class MetalCubeView: MTKView {
    /// How long the cube's edge is, as a share of the room it is given: 1
    /// turns corner to corner inside the view.
    var cubeSize: Double = 0.6 {
        didSet { if cubeSize != oldValue { drawIfStill() } }
    }

    /// Which colour the cube is painted, as the member number the Swift side
    /// sends: teal 0, amber 1, violet 2. Anything else is teal.
    var color: Int32 = 0 {
        didSet { if color != oldValue { drawIfStill() } }
    }

    /// Whether the cube turns. Stopped, it holds the angle it had.
    var isSpinning: Bool = true {
        didSet {
            guard isSpinning != oldValue else { return }

            // The clock restarts with the motion, or the time spent stopped
            // would arrive as one jump.
            lastTime = CACurrentMediaTime()
            resumeOrStop()
        }
    }

    private static let colors: [SIMD3<Float>] = [
        SIMD3(0.161, 0.722, 0.678),
        SIMD3(0.961, 0.710, 0.275),
        SIMD3(0.580, 0.443, 0.929),
    ]

    /// The eight corners as six faces, each face two triangles. `xyz` is the
    /// corner and `w` is how brightly that face takes the colour - which is
    /// what makes a solid read as a solid.
    private static let corners: [SIMD4<Float>] = {
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, Float)] = [
            (SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(1, 1, 1), SIMD3(1, -1, 1), 1.00),
            (SIMD3(-1, -1, -1), SIMD3(-1, 1, -1), SIMD3(-1, 1, 1), SIMD3(-1, -1, 1), 0.55),
            (SIMD3(-1, 1, -1), SIMD3(1, 1, -1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1), 0.88),
            (SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, -1, 1), SIMD3(-1, -1, 1), 0.42),
            (SIMD3(-1, -1, 1), SIMD3(1, -1, 1), SIMD3(1, 1, 1), SIMD3(-1, 1, 1), 0.97),
            (SIMD3(-1, -1, -1), SIMD3(1, -1, -1), SIMD3(1, 1, -1), SIMD3(-1, 1, -1), 0.50),
        ]

        return faces.flatMap { a, b, c, d, shade in
            [a, b, c, a, c, d].map { SIMD4($0.x, $0.y, $0.z, shade) }
        }
    }()

    /// What the vertex function is handed for the whole frame.
    ///
    /// Its layout is the shader's: a 4x4 of floats, then four floats. Both
    /// sides measure 80 bytes, which is what lets it cross as raw bytes.
    private struct Uniforms {
        var transform: simd_float4x4
        var color: SIMD4<Float>
    }

    private let queue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private var depth: MTLDepthStencilState?
    private var mesh: MTLBuffer?

    private var angle: Double = 0
    private var lastTime: CFTimeInterval = CACurrentMediaTime()

    /// The view, its pipeline and its mesh, built once.
    ///
    /// A machine with no Metal device leaves the pipeline empty and the view
    /// draws its background alone - a gallery is worth more than a crash.
    init() {
        let device = MTLCreateSystemDefaultDevice()
        queue = device?.makeCommandQueue()

        super.init(frame: .zero, device: device)

        colorPixelFormat = .bgra8Unorm
        depthStencilPixelFormat = .depth32Float
        clearColor = MTLClearColor(red: 0.102, green: 0.090, blue: 0.145, alpha: 1)
        preferredFramesPerSecond = 60

        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true

        guard let device else { return }

        mesh = device.makeBuffer(
            bytes: Self.corners,
            length: MemoryLayout<SIMD4<Float>>.stride * Self.corners.count)

        let describedDepth = MTLDepthStencilDescriptor()
        describedDepth.depthCompareFunction = .less
        describedDepth.isDepthWriteEnabled = true
        depth = device.makeDepthStencilState(descriptor: describedDepth)

        pipeline = Self.pipeline(on: device, colorFormat: colorPixelFormat)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("MetalCubeView is created in code")
    }

    /// Square, and big enough to see a solid turn in.
    override var intrinsicContentSize: NSSize {
        NSSize(width: 240, height: 240)
    }

    /// Nothing turns while the view is off screen, and nothing is left turning
    /// behind it: the loop stops with the window it was shown in.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        lastTime = CACurrentMediaTime()
        resumeOrStop()
    }

    /// One frame: the angle the clock has reached, the cube at the size and
    /// colour it was given.
    override func draw(_ dirtyRect: NSRect) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastTime
        lastTime = now

        // Only a turning cube moves with the clock. Stopped, the frame drawn
        // for a changed size or colour finds the angle where it was left.
        if isSpinning {
            angle += elapsed
        }

        guard let pipeline, let mesh, let queue,
              let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let buffer = queue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass),
              drawableSize.height > 0
        else { return }

        var uniforms = Uniforms(
            transform: transform(aspect: Float(drawableSize.width / drawableSize.height)),
            color: Self.paint(color))

        encoder.setRenderPipelineState(pipeline)
        encoder.setDepthStencilState(depth)
        encoder.setVertexBuffer(mesh, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Self.corners.count)
        encoder.endEncoding()

        buffer.present(drawable)
        buffer.commit()
    }

    /// Where the cube stands, how big it is, and how it is turned - one matrix
    /// the vertex function multiplies each corner by.
    private func transform(aspect: Float) -> simd_float4x4 {
        let scale = Float(max(0, min(1, cubeSize)))
        let turn = Float(angle)

        return Self.perspective(fieldOfView: 50 * .pi / 180, aspect: aspect)
            * Self.translation(z: -4)
            * Self.rotation(aroundX: turn * 0.35)
            * Self.rotation(aroundY: turn * 0.60)
            * Self.scaling(scale)
    }

    /// The colour a member number names, opaque - teal for a number naming
    /// none, so a value from outside the vocabulary paints rather than
    /// vanishes.
    private static func paint(_ color: Int32) -> SIMD4<Float> {
        let index = Int(color)
        let rgb = colors.indices.contains(index) ? colors[index] : colors[0]

        return SIMD4(rgb, 1)
    }

    /// Turning, or stopped where it stands - and never running for a view no
    /// window shows.
    private func resumeOrStop() {
        isPaused = window == nil || !isSpinning
    }

    /// Draws the one frame a stopped cube needs to show a changed size or
    /// colour. A turning one is already drawing.
    private func drawIfStill() {
        guard isPaused, window != nil else { return }

        draw()
    }

    // MARK: - The shaders, and the arithmetic behind the matrix

    /// The pipeline, from shader source compiled as the view is made.
    ///
    /// A vertex is ONE `float4`: the corner in `xyz` and the face's brightness
    /// in `w`, so there is no struct whose padding the two languages could
    /// measure differently.
    private static func pipeline(
        on device: MTLDevice, colorFormat: MTLPixelFormat
    ) -> MTLRenderPipelineState? {
        let source = """
            #include <metal_stdlib>
            using namespace metal;

            struct Uniforms {
                float4x4 transform;
                float4 color;
            };

            struct Painted {
                float4 position [[position]];
                float4 color;
            };

            vertex Painted cube_vertex(const device float4 *corners [[buffer(0)]],
                                       constant Uniforms &uniforms [[buffer(1)]],
                                       uint id [[vertex_id]]) {
                float4 corner = corners[id];

                Painted out;
                out.position = uniforms.transform * float4(corner.xyz, 1.0);
                out.color = float4(uniforms.color.rgb * corner.w, 1.0);
                return out;
            }

            fragment float4 cube_fragment(Painted in [[stage_in]]) {
                return in.color;
            }
            """

        guard let library = try? device.makeLibrary(source: source, options: nil) else { return nil }

        let described = MTLRenderPipelineDescriptor()
        described.vertexFunction = library.makeFunction(name: "cube_vertex")
        described.fragmentFunction = library.makeFunction(name: "cube_fragment")
        described.colorAttachments[0].pixelFormat = colorFormat
        described.depthAttachmentPixelFormat = .depth32Float

        return try? device.makeRenderPipelineState(descriptor: described)
    }

    private static func perspective(fieldOfView: Float, aspect: Float) -> simd_float4x4 {
        let near: Float = 0.1
        let far: Float = 100
        let y = 1 / tan(fieldOfView * 0.5)
        let x = y / max(aspect, 0.0001)
        let z = far / (near - far)

        return simd_float4x4(columns: (
            SIMD4(x, 0, 0, 0),
            SIMD4(0, y, 0, 0),
            SIMD4(0, 0, z, -1),
            SIMD4(0, 0, z * near, 0)))
    }

    private static func translation(z: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4(1, 0, 0, 0),
            SIMD4(0, 1, 0, 0),
            SIMD4(0, 0, 1, 0),
            SIMD4(0, 0, z, 1)))
    }

    private static func rotation(aroundX angle: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4(1, 0, 0, 0),
            SIMD4(0, cos(angle), sin(angle), 0),
            SIMD4(0, -sin(angle), cos(angle), 0),
            SIMD4(0, 0, 0, 1)))
    }

    private static func rotation(aroundY angle: Float) -> simd_float4x4 {
        simd_float4x4(columns: (
            SIMD4(cos(angle), 0, -sin(angle), 0),
            SIMD4(0, 1, 0, 0),
            SIMD4(sin(angle), 0, cos(angle), 0),
            SIMD4(0, 0, 0, 1)))
    }

    private static func scaling(_ scale: Float) -> simd_float4x4 {
        simd_float4x4(diagonal: SIMD4(scale, scale, scale, 1))
    }
}

// MARK: - Registration

extension MetalCubeView {
    /// Adds the cube for `MetalCubeContract`. Said once, before the application
    /// runs.
    ///
    /// A view that draws on the GPU registers exactly like one that draws with a
    /// layer: an `MTKView` is an `NSView`. It reports nothing, so `create` only
    /// makes it - every member here goes one way, from the description to the
    /// frames. The cube is declared for this host alone, and this file names it
    /// with no condition around it because nothing but an AppKit build compiles
    /// this folder.
    @MainActor
    static func register() {
        StateUIControls.add(MetalCubeContract.self, create: { _ -> MetalCubeView in
            MetalCubeView()
        }) { cube in
            cube.property(MetalCubeContract.size) { view, size in
                view.cubeSize = size ?? 0.6
            }
            cube.property(MetalCubeContract.color) { view, color in
                view.color = (color ?? .teal).rawValue
            }
            cube.property(MetalCubeContract.isSpinning) { view, spinning in
                view.isSpinning = spinning ?? true
            }
        }
    }
}
