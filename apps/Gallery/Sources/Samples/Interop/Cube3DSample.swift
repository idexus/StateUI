#if APPKIT || GTK || WINUI
import StateUI

/// A cube the host draws on the GPU - Metal on AppKit, OpenGL 3.3 on GTK, Direct3D 11.1 on WinUI - with
/// everything about it described from this side.
struct Cube3DSample: SampleContent, ExampleContent {
    @State private var size = 0.6
    @State private var color = 0
    @State private var spinning = true

    #if APPKIT
    static let id = "appKitMetal"
    static let title = "A Metal view"
    static let summary = "A cube drawn on the GPU by the host, sized and coloured from StateUI."
    #elseif GTK
    static let id = "gtkOpenGL"
    static let title = "An OpenGL view"
    static let summary = "A cube drawn by OpenGL 3.3 in the host, sized and coloured from StateUI."
    #else
    static let id = "winUIDirect3D"
    static let title = "A Direct3D view"
    static let summary = "A cube drawn by Direct3D 11.1 in the host, sized and coloured from StateUI."
    #endif

    static let codeHeading = "In StateUI"

    /// The names the picker offers, in the order `CubeColor` declares them -
    /// so the chosen index IS the vocabulary's member number.
    static let colors = ["Teal", "Amber", "Violet"]

    static let code = """
        public enum CubeColor: Int32, CaseIterable, HostRepresentable {
            case teal = 0, amber = 1, violet = 2
        }

        public enum Cube3DContract: ElementContract {
            public static let nodeType: NodeType = "Gallery.Cube3D"
            public static let tiers: [any Contract.Type] = [ViewContract.self]

            // A size HAS a half way, so a change travels. A vocabulary and a
            // flag have none, so theirs do not.
            public static let size = ElementProperty<Self, Double>("size")
            public static let color = ElementProperty<Self, CubeColor>("color", travels: false)
            public static let isSpinning = ElementProperty<Self, Bool>("isSpinning", travels: false)

            public static let members: [any ContractMember] = [size, color, isSpinning]
        }

        public struct Cube3D: View {
            public var node = Node(contract: Cube3DContract.self)

            public init() {}

            public func size(_ value: Double) -> Self {
                setValue(Cube3DContract.size, value)
            }

            // HANDED OVER: the host carries the property from the state, so
            // the view writing the line is not a reader of it. `.inOut`,
            // because the host reports where a walk has got to.
            public func size(_ state: Binding<Double>) -> Modified {
                setValue(Cube3DContract.size, on: state, mode: .inOut, kind: .property)
            }

            public func color(_ value: CubeColor) -> Self {
                setValue(Cube3DContract.color, value)
            }

            public func isSpinning(_ value: Bool) -> Self {
                setValue(Cube3DContract.isSpinning, value)
            }
        }

        @State private var size = 0.6
        @State private var color = 0
        @State private var spinning = true

        static let colors = ["Teal", "Amber", "Violet"]

        VStack {
            // NOTHING here reads `size`. The cube is handed the state, and the
            // caption is a CONVERSION of that same journey - both worked out
            // by the host on its own frames. So dragging the thumb the width
            // of the page builds this closure not once.
            DebugInfoLabel()

            Cube3D()
                .size($size)
                .color(CubeColor(rawValue: Int32(color)) ?? .teal)
                .isSpinning(spinning)

            Label()
                .text($size.journey.convert { "Edge: \\(Int($0.value * 100))% of the view" })

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

    #if APPKIT
    static let hostCode = HostCode(
        heading: "In AppKit",
        language: .swift,
        code: """
            // Platforms/AppKit/Host/MetalCube3DView.swift - an ordinary MTKView
            // that knows nothing of StateUI. It draws in `draw(_:)`, so it
            // needs no delegate beside it.
            final class MetalCube3DView: MTKView {
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

            // And its registration, at the end of MetalCube3DView.swift. The
            // cube reports nothing, so `create` only makes the view: every
            // member here goes one way, from the description to the frames.
            extension MetalCube3DView {
                @MainActor
                static func register() {
                    StateUIControls.add(Cube3DContract.self, create: { _ -> MetalCube3DView in
                        MetalCube3DView()
                    }) { cube in
                        cube.property(Cube3DContract.size) { view, size in
                            view.cubeSize = size ?? 0.6
                        }
                        cube.property(Cube3DContract.color) { view, color in
                            view.color = (color ?? .teal).rawValue
                        }
                        cube.property(Cube3DContract.isSpinning) { view, spinning in
                            view.isSpinning = spinning ?? true
                        }
                    }
                }
            }
            """)
    #elseif GTK
    static let hostCode = HostCode(
        heading: "In GTK",
        language: .swift,
        code: """
            // Platforms/GTK/Host/OpenGLCube3DWidget.swift - a GtkGLArea asking for
            // OpenGL 3.3 core, which draws it through libepoxy, the loader GTK
            // itself draws with. A GTKControl is an object holding its widget.
            @MainActor
            final class OpenGLCube3DWidget: GTKControl {
                let widget: UnsafeMutablePointer<GtkWidget>

                var cubeSize = 0.6 {
                    didSet { if cubeSize != oldValue { gtk_gl_area_queue_render(area) } }
                }
                var color = CubeColor.teal {
                    didSet { if color != oldValue { gtk_gl_area_queue_render(area) } }
                }
                var isSpinning = true {
                    didSet { if isSpinning != oldValue { followClock() } }
                }

                init() {
                    widget = gtk_gl_area_new()
                    g_object_ref_sink(widget)
                    gtk_gl_area_set_required_version(area, 3, 3)
                    gtk_gl_area_set_allowed_apis(area, GDK_GL_API_GL)
                    gtk_gl_area_set_has_depth_buffer(area, 1)
                    // "realize" compiles the shaders and loads the corners,
                    // "render" draws a frame, "unrealize" lets them go - each
                    // a C callback handed the control as its data.
                    followClock()
                }

                // GTK ticks only a mapped widget: the cube stops turning
                // behind a page the user has left, and a stopped cube still
                // owes one frame to a value that changed.
                private func followClock() {
                    if isSpinning, tick == 0 {
                        tick = gtk_widget_add_tick_callback(widget, turn, me, nil)
                    } else if !isSpinning, tick != 0 {
                        gtk_widget_remove_tick_callback(widget, tick)
                        tick = 0
                    }
                }

                private func render() -> gboolean {
                    epoxy_glClearColor(0.102, 0.090, 0.145, 1)
                    epoxy_glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
                    epoxy_glEnable(GLenum(GL_DEPTH_TEST))
                    epoxy_glUseProgram(program)
                    epoxy_glUniformMatrix4fv(transformAt, 1, GLboolean(GL_FALSE), &transform)
                    epoxy_glUniform4f(colorAt, red, green, blue, 1)
                    epoxy_glBindVertexArray(vertexArray)
                    epoxy_glDrawArrays(GLenum(GL_TRIANGLES), 0, 36)
                    return 1
                }
            }

            extension OpenGLCube3DWidget {
                @MainActor
                static func register() {
                    StateUIControls.add(Cube3DContract.self, create: { _ in OpenGLCube3DWidget() }) { cube in
                        cube.property(Cube3DContract.size) { control, size in
                            control.cubeSize = size ?? 0.6
                        }
                        cube.property(Cube3DContract.color) { control, color in
                            control.color = color ?? .teal
                        }
                        cube.property(Cube3DContract.isSpinning) { control, spinning in
                            control.isSpinning = spinning ?? true
                        }
                    }
                }
            }
            """)
    #else
    static let hostCode = HostCode(
        heading: "In WinUI",
        language: .swift,
        code: """
            // Platforms/WinUI/Host/Direct3DCube3DControl.swift. The cube is a
            // SwapChainPanel the gallery's own relay makes - C++/WinRT in
            // Platforms/WinUI/Relay/Cube3D.cpp - and draws into with a
            // Direct3D 11.1 device, following WinUI's frames only while it
            // spins and stands on screen. A WinUIControl holds its element.
            @MainActor
            final class Direct3DCube3DControl: WinUIControl {
                let element: OpaquePointer

                var cubeSize = 0.6 { didSet { tell() } }
                var color = CubeColor.teal { didSet { tell() } }
                var isSpinning = true { didSet { tell() } }

                init() {
                    element = gallery_cube_make()!
                }

                isolated deinit {
                    gallery_cube_close(element)
                    gallery_winui_release(element)
                }

                private func tell() {
                    gallery_cube_set(element, cubeSize, color.rawValue, isSpinning)
                }
            }

            extension Direct3DCube3DControl {
                @MainActor
                static func register() {
                    StateUIControls.add(Cube3DContract.self, create: { _ in Direct3DCube3DControl() }) { cube in
                        cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
                        cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
                        cube.property(Cube3DContract.isSpinning) { control, spinning in
                            control.isSpinning = spinning ?? true
                        }
                    }
                }
            }
            """)
    #endif

    var content: any View {
        VStack {
            DebugInfoLabel()

            Cube3D()
                .size($size)
                .color(CubeColor(rawValue: Int32(color)) ?? .teal)
                .isSpinning(spinning)
                .accessibilityIdentifier("cube3D.cube")
                .accessibilityLabel("Cube")
                .horizontalAlignment(.center)

            Label()
                .text($size.journey.convert { "Edge: \(Int($0.value * 100))% of the view" })
                .fontSize(17)
                .horizontalTextAlignment(.center)

            Slider($size)
                .accessibilityIdentifier("cube3D.size")
                .accessibilityLabel("Edge")
                .minimum(0.2)
                .maximum(1)
                .tint(Palette.accent)

            Picker(Self.colors)
                .accessibilityIdentifier("cube3D.color")
                .accessibilityLabel("Color")
                .selectedIndex($color)
                .title("Color")

            HStack {
                Label("Spin")
                    .fontSize(14)
                    .verticalAlignment(.center)

                Switch($spinning)
                    .accessibilityIdentifier("cube3D.spin")
                    .accessibilityLabel("Spin")
                    .tint(Palette.accent)
            }
            .spacing(12)
            .horizontalAlignment(.center)
        }
        .spacing(12)
    }

    #if APPKIT
    private static let drawnBy = "The cube is an `MTKView` the gallery registers with "
        + "`StateUIControls.add`, exactly as it registers a view that draws with a layer. A "
        + "view that draws on the GPU is still an `NSView`, so the registration has nothing "
        + "extra to say."
    private static let stopsWith = "The loop also stops with the window, so nothing is "
        + "left turning behind a page you have left."
    #elseif GTK
    private static let drawnBy = "The cube is a `GtkGLArea` drawing with OpenGL 3.3 core, "
        + "held by a `GTKControl` the gallery registers with `StateUIControls.add` - a "
        + "widget like any other, so the registration has nothing extra to say."
    private static let stopsWith = "GTK ticks only a widget on screen, so nothing is "
        + "left turning behind a page you have left."
    #else
    private static let drawnBy = "The cube is a `SwapChainPanel` drawing with Direct3D 11.1, "
        + "made by the gallery's own C++/WinRT relay and held by a `WinUIControl` the gallery "
        + "registers with `StateUIControls.add` - an element like any other, so the "
        + "registration has nothing extra to say."
    private static let stopsWith = "The cube follows WinUI's frames only while it stands on "
        + "screen, so nothing is left turning behind a page you have left."
    #endif

    var notes: Element? {
        VStack {
            Label(Self.drawnBy)
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The edge is HANDED OVER: `.size($size)` gives the host the state "
                + "itself, and the caption is a conversion of that same journey. Nothing "
                + "here reads `size`, so a drag builds this example not once - the cube "
                + "grows and the number counts up on the host's own frames. The colour "
                + "and the spin are plain values, described again on the one build a "
                + "pick or a flip costs.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Nothing about the drawing crosses. What travels is a number, a "
                + "vocabulary member and a flag; the corners, the matrix and the frames "
                + "are the host's own, and this side never learns they exist.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Turning the spin off stops the host's render loop rather than hiding "
                + "it: the cube holds the angle it had, and a changed size or colour "
                + "still draws the one frame it needs. " + Self.stopsWith)
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("One `Cube3D` on this side, drawn by each host in its own way. An "
                + "element only some hosts can honestly realize is declared only for "
                + "them - this one stands under the same condition as its sample, so no "
                + "other host is held to a promise it cannot keep.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
