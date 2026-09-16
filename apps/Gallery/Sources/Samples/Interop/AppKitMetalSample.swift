#if APPKIT
import StateUI

/// A cube the host draws on the GPU, with everything about it described from
/// this side.
struct AppKitMetalSample: SampleContent, ExampleContent {
    @State private var size = 0.6
    @State private var color = 0
    @State private var spinning = true

    static let id = "appKitMetal"
    static let title = "A Metal view"
    static let summary = "A cube drawn on the GPU by the host, sized and coloured from StateUI."

    static let codeHeading = "In StateUI"

    /// The names the picker offers, in the order `CubeColor` declares them -
    /// so the chosen index IS the vocabulary's member number.
    static let colors = ["Teal", "Amber", "Violet"]

    static let code = """
        public enum CubeColor: Int32, CaseIterable, HostRepresentable {
            case teal = 0, amber = 1, violet = 2
        }

        public enum MetalCubeContract: ElementContract {
            public static let nodeType: NodeType = "Gallery.MetalCube"
            public static let tiers: [any Contract.Type] = [ViewContract.self]

            // A size HAS a half way, so a change travels. A vocabulary and a
            // flag have none, so theirs do not.
            public static let size = ElementProperty<Self, Double>("size")
            public static let color = ElementProperty<Self, CubeColor>("color", travels: false)
            public static let isSpinning = ElementProperty<Self, Bool>("isSpinning", travels: false)

            public static let members: [any ContractMember] = [size, color, isSpinning]
        }

        public struct MetalCube: View {
            public var node = Node(contract: MetalCubeContract.self)

            public init() {}

            public func size(_ value: Double) -> Self {
                setValue(MetalCubeContract.size, value)
            }

            public func color(_ value: CubeColor) -> Self {
                setValue(MetalCubeContract.color, value)
            }

            public func isSpinning(_ value: Bool) -> Self {
                setValue(MetalCubeContract.isSpinning, value)
            }
        }

        @State private var size = 0.6
        @State private var color = 0
        @State private var spinning = true

        static let colors = ["Teal", "Amber", "Violet"]

        VStack {
            // The size is read here, so every step of the drag builds this
            // closure - which is what a get on a dragged value costs.
            DebugInfoLabel()

            MetalCube()
                .size(size)
                .color(CubeColor(rawValue: Int32(color)) ?? .teal)
                .isSpinning(spinning)

            Label("Edge: \\(Int(size * 100))% of the view")

            Slider($size)
                .minimum(0.2)
                .maximum(1)

            Picker(Self.colors)
                .selectedIndex($color)
                .title("Color")

            HStack {
                Label("Spin")

                Switch($spinning)
            }
        }
        """

    static let hostCode = HostCode(
        heading: "In AppKit",
        language: .swift,
        code: """
            // Platforms/AppKit/Host/MetalCubeView.swift - an ordinary MTKView
            // that knows nothing of StateUI. It draws in `draw(_:)`, so it
            // needs no delegate beside it.
            final class MetalCubeView: MTKView {
                var cubeSize: Double = 0.6 {
                    didSet { if cubeSize != oldValue { drawIfStill() } }
                }

                // A number, because a closed vocabulary crosses as its
                // member: teal 0, amber 1, violet 2.
                var color: Int32 = 0 {
                    didSet { if color != oldValue { drawIfStill() } }
                }

                var isSpinning: Bool = true {
                    didSet {
                        guard isSpinning != oldValue else { return }

                        // The clock restarts with the motion, or the time
                        // spent stopped would arrive as one jump.
                        lastTime = CACurrentMediaTime()
                        resumeOrStop()
                    }
                }

                init() {
                    let device = MTLCreateSystemDefaultDevice()
                    queue = device?.makeCommandQueue()

                    super.init(frame: .zero, device: device)

                    colorPixelFormat = .bgra8Unorm
                    depthStencilPixelFormat = .depth32Float
                    preferredFramesPerSecond = 60

                    guard let device else { return }

                    mesh = device.makeBuffer(bytes: Self.corners, length: ...)
                    pipeline = Self.pipeline(on: device, colorFormat: colorPixelFormat)
                }

                override func draw(_ dirtyRect: NSRect) {
                    let now = CACurrentMediaTime()

                    // Only a turning cube moves with the clock. Stopped, the
                    // frame drawn for a changed size or colour finds the angle
                    // where it was left.
                    if isSpinning { angle += now - lastTime }
                    lastTime = now

                    var uniforms = Uniforms(
                        transform: transform(aspect: ...),
                        color: Self.paint(color))

                    encoder.setRenderPipelineState(pipeline)
                    encoder.setDepthStencilState(depth)
                    encoder.setVertexBuffer(mesh, offset: 0, index: 0)
                    encoder.setVertexBytes(
                        &uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
                    encoder.drawPrimitives(
                        type: .triangle, vertexStart: 0, vertexCount: 36)
                }

                // Nothing is left turning behind the view: the loop stops
                // with the window that showed it.
                override func viewDidMoveToWindow() {
                    super.viewDidMoveToWindow()

                    lastTime = CACurrentMediaTime()
                    resumeOrStop()
                }

                private func resumeOrStop() {
                    isPaused = window == nil || !isSpinning
                }
            }

            // The shaders, compiled FROM SOURCE as the view is made - so the
            // application ships no .metal file and its build needs nothing
            // added to it. A vertex is one float4: the corner in xyz and the
            // face's brightness in w, so no struct's padding can be measured
            // differently by the two languages.
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

            // And the registration, in GalleryControls.register(). The cube
            // reports nothing, so `create` only makes the view: every member
            // here goes one way, from the description to the frames.
            StateUIAppKit.realizes(MetalCubeContract.self, create: { _ -> MetalCubeView in
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
            """)

    var content: any View {
        VStack {
            DebugInfoLabel()

            MetalCube()
                .size(size)
                .color(CubeColor(rawValue: Int32(color)) ?? .teal)
                .isSpinning(spinning)
                .accessibilityIdentifier("metal.cube")
                .accessibilityLabel("Cube")
                .horizontalAlignment(.center)

            Label("Edge: \(Int(size * 100))% of the view")
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Slider($size)
                .accessibilityIdentifier("metal.size")
                .accessibilityLabel("Edge")
                .minimum(0.2)
                .maximum(1)
                .tint(Palette.accent)

            Picker(Self.colors)
                .accessibilityIdentifier("metal.color")
                .accessibilityLabel("Color")
                .selectedIndex($color)
                .title("Color")

            HStack {
                Label("Spin")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($spinning)
                    .accessibilityIdentifier("metal.spin")
                    .accessibilityLabel("Spin")
                    .tint(Palette.accent)
            }
            .spacing(12)
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The cube is an `MTKView` the gallery registers with "
                + "`StateUIAppKit.realizes`, exactly as it registers a view that draws "
                + "with a layer. A view that draws on the GPU is still an `NSView`, so "
                + "the registration has nothing extra to say.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Nothing about the drawing crosses. What travels is a number, a "
                + "vocabulary member and a flag; the corners, the matrix and the frames "
                + "are the host's own, and this side never learns they exist.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Turning the spin off stops the host's render loop rather than hiding "
                + "it: the cube holds the angle it had, and a changed size or colour "
                + "still draws the one frame it needs. The loop also stops with the "
                + "window, so nothing is left turning behind a page you have left.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An element only one host can honestly realize is declared only for "
                + "that host - this one stands under the same condition as its samples, "
                + "so no other host is held to a promise it cannot keep.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
