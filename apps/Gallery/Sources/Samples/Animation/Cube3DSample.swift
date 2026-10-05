#if APPKIT || UIKIT || GTK || WINUI || ANDROID || WEB
import StateUI

/// A cube the host draws on the GPU - Metal on AppKit and UIKit, OpenGL 3.3 on GTK, Direct3D 11.1 on WinUI,
/// OpenGL ES 3.0 on Android, WebGL 2 on the Web - with everything about it described from this side.
struct Cube3DSample: SampleContent, ExampleContent {
    @State private var size = 0.6
    @State private var color = 0
    @State private var spinning = true

    #if APPKIT
    static let id = "appKitMetal"
    static let title = "A Metal view"
    static let summary = "A cube drawn on the GPU by the host, sized and coloured from StateUI."
    #elseif UIKIT
    static let id = "uiKitMetal"
    static let title = "A Metal view"
    static let summary = "A cube drawn on the GPU by the host, sized and coloured from StateUI."
    #elseif GTK
    static let id = "gtkOpenGL"
    static let title = "An OpenGL view"
    static let summary = "A cube drawn by OpenGL 3.3 in the host, sized and coloured from StateUI."
    #elseif WINUI
    static let id = "winUIDirect3D"
    static let title = "A Direct3D view"
    static let summary = "A cube drawn by Direct3D 11.1 in the host, sized and coloured from StateUI."
    #elseif WEB
    static let id = "webWebGL"
    static let title = "A WebGL view"
    static let summary = "A cube drawn by WebGL 2 in the page, sized and coloured from StateUI."
    #else
    static let id = "androidOpenGLES"
    static let title = "An OpenGL ES view"
    static let summary = "A cube drawn by OpenGL ES 3.0 in the host, sized and coloured from StateUI."
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

        public struct Cube3D: ElementView {
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

            Text()
                .text($size.journey.convert { "Edge: \\(Int($0.value * 100))% of the view" })

            Slider($size)
                .minimum(0.2)
                .maximum(1)

            Picker(Self.colors)
                .selectedIndex($color)
                .placeholder("Color")

            HStack {
                Text("Spin")

                Switch($spinning)
            }
        }
        """

    #if APPKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
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
            """),
        .metal("""
            // The shaders MetalCube3DView compiles FROM SOURCE as it is made - so
            // the application ships no .metal file and its build needs nothing
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
            """))
    #elseif UIKIT
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/UIKit/Host/MetalCube3DView.swift - an ordinary MTKView
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

                override func draw(_ rect: CGRect) {
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
                override func didMoveToWindow() {
                    super.didMoveToWindow()

                    lastTime = CACurrentMediaTime()
                    resumeOrStop()
                }

                private func resumeOrStop() {
                    isPaused = window == nil || !isSpinning
                }
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
            """),
        .metal("""
            // The shaders MetalCube3DView compiles FROM SOURCE as it is made - so
            // the application ships no .metal file and its build needs nothing
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
            """))
    #elseif GTK
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
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
            """),
        .glsl("""
            // The shaders OpenGLCube3DWidget.swift compiles from source for OpenGL 3.3
            // core, as its area is realized. A corner carries its face's brightness in
            // w; the colour is the frame's.
            #version 330 core
            layout(location = 0) in vec4 corner;
            uniform mat4 transform;
            uniform vec4 color;
            out vec4 painted;
            void main() {
                gl_Position = transform * vec4(corner.xyz, 1.0);
                painted = vec4(color.rgb * corner.w, color.a);
            }

            #version 330 core
            in vec4 painted;
            out vec4 fragment;
            void main() { fragment = painted; }
            """))
    #elseif WINUI
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
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
            """),
        .cpp("""
            // Platforms/WinUI/Relay/Cube3D.cpp - a SwapChainPanel, an element that
            // knows nothing of StateUI, drawn into by a Direct3D 11.1 device. It
            // follows WinUI's frames only while it spins and stands on screen, and a
            // value changed while it stands still draws the one frame it needs.
            namespace {
                // … the device, the shaders below, the corners and the swap chain,
                // made once and sized again with the panel (standChain)

                // Clears to the housing's colour and draws the cube: turned, scaled and seen in perspective.
                void draw(Cube &cube) {
                    auto panel = cube.panel.get();
                    if (!panel || panel.ActualWidth() < 1 || panel.ActualHeight() < 1) return;
                    standChain(cube, panel);

                    float const housing[4] = {0.102f, 0.090f, 0.145f, 1};
                    auto target = cube.target.get();
                    cube.context->OMSetRenderTargets(1, &target, cube.depth.get());
                    cube.context->ClearRenderTargetView(target, housing);
                    cube.context->ClearDepthStencilView(cube.depth.get(), D3D11_CLEAR_DEPTH, 1, 0);
                    D3D11_VIEWPORT viewport{0, 0, static_cast<float>(cube.width), static_cast<float>(cube.height), 0, 1};
                    cube.context->RSSetViewports(1, &viewport);

                    Frame frame{};
                    transform(double(cube.width) / cube.height, cube.angle, std::clamp(cube.size, 0.0, 1.0), frame.transform);
                    auto const &paint = paints[std::clamp(cube.color, 0, 2)];
                    std::copy(paint, paint + 3, frame.color);
                    frame.color[3] = 1;
                    cube.context->UpdateSubresource(cube.frame.get(), 0, nullptr, &frame, 0, 0);

                    UINT const stride = 4 * sizeof(float), offset = 0;
                    auto corners = cube.corners.get();
                    auto constants = cube.frame.get();
                    cube.context->IASetInputLayout(cube.layout.get());
                    cube.context->IASetVertexBuffers(0, 1, &corners, &stride, &offset);
                    cube.context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
                    cube.context->VSSetShader(cube.vertexShader.get(), nullptr, 0);
                    cube.context->VSSetConstantBuffers(0, 1, &constants);
                    cube.context->PSSetShader(cube.pixelShader.get(), nullptr, 0);
                    cube.context->RSSetState(cube.bothSides.get());
                    cube.context->OMSetDepthStencilState(cube.nearest.get(), 0);
                    cube.context->Draw(36, 0);
                    check_hresult(cube.chain->Present(1, 0));
                }

                // Follows WinUI's frames while the cube spins and stands on screen, and lets go of them otherwise.
                void followFrames(std::shared_ptr<Cube> const &cube) {
                    auto follows = static_cast<bool>(cube->rendering);
                    if (cube->spinning && cube->shown && !follows) {
                        cube->lastFrame = -1;
                        std::weak_ptr<Cube> weak = cube;
                        cube->rendering = xaml::Media::CompositionTarget::Rendering(
                            [weak](auto const &, winrt::Windows::Foundation::IInspectable const &args) {
                                auto cube = weak.lock();
                                if (!cube) return;
                                try {
                                    auto now = std::chrono::duration<double>(
                                        args.as<xaml::Media::RenderingEventArgs>().RenderingTime()).count();
                                    if (cube->lastFrame >= 0) cube->angle += now - cube->lastFrame;
                                    cube->lastFrame = now;
                                    draw(*cube);
                                } catch (...) {
                                    report("drawing the cube");
                                }
                            });
                    } else if (!(cube->spinning && cube->shown) && follows) {
                        xaml::Media::CompositionTarget::Rendering(cube->rendering);
                        cube->rendering = {};
                    }
                }
            }

            extern "C" GalleryObjectRef gallery_cube_make(void) {
                try {
                    controls::SwapChainPanel panel;
                    panel.MinWidth(240);
                    panel.MinHeight(240);
                    auto cube = std::make_shared<Cube>();
                    cube->panel = winrt::make_weak(panel);
                    std::weak_ptr<Cube> weak = cube;
                    panel.Loaded([weak](auto const &, auto const &) {
                        if (auto cube = weak.lock()) {
                            cube->shown = true;
                            followFrames(cube);
                            try { draw(*cube); } catch (...) { report("drawing the cube"); }
                        }
                    });
                    panel.Unloaded([weak](auto const &, auto const &) {
                        if (auto cube = weak.lock()) {
                            cube->shown = false;
                            followFrames(cube);
                        }
                    });
                    auto redraw = [weak](auto const &, auto const &) {
                        if (auto cube = weak.lock()) {
                            try { draw(*cube); } catch (...) { report("drawing the cube"); }
                        }
                    };
                    panel.SizeChanged(redraw);
                    panel.CompositionScaleChanged(redraw);
                    cubes[identity(panel)] = cube;
                    return detach(panel);
                } catch (...) {
                    report("making a cube");
                    return nullptr;
                }
            }

            extern "C" void gallery_cube_set(GalleryObjectRef handle, double size, int32_t color, bool spinning) {
                try {
                    auto found = cube(handle);
                    if (!found) return;
                    found->size = size;
                    found->color = color;
                    found->spinning = spinning;
                    followFrames(found);
                    if (found->shown) draw(*found);
                } catch (...) {
                    report("setting the cube");
                }
            }
            """),
        .hlsl("""
            // The shaders Cube3D.cpp compiles from source with D3DCompile, vs_5_0 and
            // ps_5_0. A corner carries its face's brightness in w; the colour is the
            // frame's.
            cbuffer Frame : register(b0) { float4x4 transform; float4 color; };
            struct Corner { float4 at : POSITION; };
            struct Painted { float4 position : SV_POSITION; float4 color : COLOR; };
            Painted vertex(Corner corner) {
                Painted painted;
                painted.position = mul(transform, float4(corner.at.xyz, 1));
                painted.color = float4(color.rgb * corner.at.w, color.a);
                return painted;
            }
            float4 pixel(Painted painted) : SV_TARGET { return painted.color; }
            """))
    #elseif WEB
    static let hostCode = HostCode(
        in: "Web",
        .swift("""
            // Platforms/Web/Host/WebGLCube3DView.swift - a WebControl holding
            // the gallery's own custom element, <gallery-cube3d>, and telling
            // it what it is through its attributes.
            @MainActor
            final class WebGLCube3DView: WebControl {
                let element = WebPageElement(tag: "gallery-cube3d")

                var cubeSize = 0.6 {
                    didSet { element.setAttribute("size", String(cubeSize)) }
                }

                // A number, because a closed vocabulary crosses as its member.
                var color = CubeColor.teal {
                    didSet { element.setAttribute("color", String(color.rawValue)) }
                }

                var isSpinning = true {
                    didSet { element.setAttribute("spinning", isSpinning ? "" : nil) }
                }
            }

            StateUIControls.add(Cube3DContract.self, create: { _ in WebGLCube3DView() }) { cube in
                cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
                cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
                cube.property(Cube3DContract.isSpinning) { control, spinning in
                    control.isSpinning = spinning ?? true
                }
            }
            """),
        .javascript("""
            // Platforms/Web/Page/cube3d.js - the element itself, which knows
            // nothing of StateUI: WebGL 2 on a canvas of its own, turning on
            // the browser's frames while it is in view.
            class Cube3D extends HTMLElement {
                static observedAttributes = ["size", "color", "spinning"];

                connectedCallback() {
                    this.seen = new IntersectionObserver(([entry]) => {
                        this.inView = entry.isIntersecting;
                        this.follow();
                    });
                    this.seen.observe(this);
                }

                attributeChangedCallback() {
                    this.follow();
                    this.draw();
                }

                follow() {
                    const turns = this.hasAttribute("spinning") && this.inView;
                    if (turns && !this.frame) {
                        const turn = (time) => {
                            this.angle += (time - this.lastFrame) / 1000;
                            this.lastFrame = time;
                            this.draw();
                            this.frame = requestAnimationFrame(turn);
                        };
                        this.frame = requestAnimationFrame(turn);
                    } else if (!turns && this.frame) {
                        cancelAnimationFrame(this.frame);
                        this.frame = 0;
                    }
                }

                draw() {
                    const gl = this.gl;
                    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
                    gl.uniformMatrix4fv(this.transformAt, false,
                        transform(this.width / this.height, this.angle, this.size));
                    gl.uniform4f(this.colorAt, ...this.color, 1);
                    gl.drawArrays(gl.TRIANGLES, 0, 36);
                }
            }

            customElements.define("gallery-cube3d", Cube3D);
            """),
        .glsl("""
            #version 300 es
            layout(location = 0) in vec4 corner;
            uniform mat4 transform;
            uniform vec4 color;
            out vec4 painted;
            void main() {
                gl_Position = transform * vec4(corner.xyz, 1.0);
                painted = vec4(color.rgb * corner.w, color.a);
            }
            """))
    #else
    static let hostCode = HostCode(
        in: InteropHost.name,
        .swift("""
            // Platforms/Android/Swift/Host/GLESCube3DView.swift. The cube is a
            // TextureView of the gallery's own Java - Cube3DView.java - that
            // hands its Surface over as it comes and goes, and asks for the
            // display's frames while it spins and stands in a window. Swift
            // draws into it with OpenGL ES 3.0, over EGL, in the gallery's C
            // module CGalleryGLES. An AndroidControl holds its view.
            @MainActor
            final class GLESCube3DView: AndroidControl {
                let view: JavaObject

                var cubeSize = 0.6 { didSet { if cubeSize != oldValue { draw() } } }
                var color = CubeColor.teal { didSet { if color != oldValue { draw() } } }
                var isSpinning = true {
                    didSet {
                        if isSpinning != oldValue { Java.call(view.reference, Self.setSpinning, .bool(isSpinning)) }
                    }
                }

                // The view's surface came: an EGL context over its window, the
                // cube's program and corners made in it, then a frame.
                func surfaceReady(
                    _ surface: jobject?, environment: UnsafeMutablePointer<JNIEnv?>?, width: Int32, height: Int32
                ) {
                    if drawing == nil, let surface, let window = ANativeWindow_fromSurface(environment, surface) {
                        drawing = Drawing(window: window)
                    }
                    drawing?.size = (width, height)
                    draw()
                }

                // One display frame while spinning: the angle moves by the
                // time since the last.
                func frame(at time: Int64) {
                    if lastFrame != 0 { angle += Double(time - lastFrame) / 1_000_000_000 }
                    lastFrame = time
                    draw()
                }
            }

            extension GLESCube3DView {
                @MainActor
                static func register() {
                    StateUIControls.add(Cube3DContract.self, create: { _ in GLESCube3DView() }) { cube in
                        cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
                        cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
                        cube.property(Cube3DContract.isSpinning) { control, spinning in
                            control.isSpinning = spinning ?? true
                        }
                    }
                }
            }
            """),
        .java("""
            // Platforms/Android/Java/com/stateui/gallery/Cube3DView.java - the surface
            // the Swift half draws the cube into: a TextureView, drawn as a view is,
            // so the opacity, transform and clip StateUI puts on every view hold for
            // it. It hands its surface over as it comes and goes, and asks for the
            // display's frames while it spins and stands in a window.
            final class Cube3DView extends TextureView implements TextureView.SurfaceTextureListener, Choreographer.FrameCallback {
                private static final float SIDE = 240;

                private final long control;
                private final float density;
                private Surface surface;
                private boolean spinning = true;
                private boolean following;

                Cube3DView(Context context, long control) {
                    super(context);
                    this.control = control;
                    density = context.getResources().getDisplayMetrics().density;
                    setSurfaceTextureListener(this);
                }

                // Whether the cube turns: frames come only while it does.
                void setSpinning(boolean value) {
                    spinning = value;
                    follow();
                }

                @Override
                protected void onMeasure(int width, int height) {
                    int side = Math.round(SIDE * density);
                    setMeasuredDimension(resolveSize(side, width), resolveSize(side, height));
                }

                @Override
                protected void onAttachedToWindow() {
                    super.onAttachedToWindow();
                    follow();
                }

                @Override
                protected void onDetachedFromWindow() {
                    super.onDetachedFromWindow();
                    follow();
                }

                @Override
                public void onSurfaceTextureAvailable(SurfaceTexture texture, int width, int height) {
                    surface = new Surface(texture);
                    GalleryNatives.surfaceReady(control, surface, width, height);
                    follow();
                }

                @Override
                public void onSurfaceTextureSizeChanged(SurfaceTexture texture, int width, int height) {
                    if (surface != null) GalleryNatives.surfaceReady(control, surface, width, height);
                }

                @Override
                public boolean onSurfaceTextureDestroyed(SurfaceTexture texture) {
                    GalleryNatives.surfaceGone(control);
                    surface.release();
                    surface = null;
                    follow();
                    return true;
                }

                @Override
                public void onSurfaceTextureUpdated(SurfaceTexture texture) {}

                @Override
                public void doFrame(long nanoseconds) {
                    if (!following) return;
                    GalleryNatives.cubeFrame(control, nanoseconds);
                    Choreographer.getInstance().postFrameCallback(this);
                }

                // Asks for frames while the cube spins on a surface in a window, and
                // for none otherwise.
                private void follow() {
                    boolean wanted = spinning && surface != null && isAttachedToWindow();
                    if (wanted == following) return;
                    following = wanted;
                    if (wanted) {
                        Choreographer.getInstance().postFrameCallback(this);
                    } else {
                        Choreographer.getInstance().removeFrameCallback(this);
                    }
                }
            }

            // Platforms/Android/Java/com/stateui/gallery/GalleryNatives.java - what
            // the view tells its Swift half, which answers each by its JNI name.
            final class GalleryNatives {
                static native void surfaceReady(long control, Surface surface, int width, int height);
                static native void surfaceGone(long control);
                static native void cubeFrame(long control, long nanoseconds);
            }
            """),
        .glsl("""
            // The shaders GLESCube3DView.swift compiles from source for OpenGL ES 3.0.
            // A corner carries its face's brightness in w; the colour is the frame's.
            #version 300 es
            layout(location = 0) in vec4 corner;
            uniform mat4 transform;
            uniform vec4 color;
            out vec4 painted;
            void main() {
                gl_Position = transform * vec4(corner.xyz, 1.0);
                painted = vec4(color.rgb * corner.w, color.a);
            }

            #version 300 es
            precision mediump float;
            in vec4 painted;
            out vec4 fragment;
            void main() { fragment = painted; }
            """))
    #endif

    var body: some View {
        VStack {
            DebugInfoLabel()

            Cube3D()
                .size($size)
                .color(CubeColor(rawValue: Int32(color)) ?? .teal)
                .isSpinning(spinning)
                .accessibilityIdentifier("cube3D.cube")
                .accessibilityLabel("Cube")
                .horizontalAlignment(.center)

            Text()
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
                .placeholder("Color")

            HStack {
                Text("Spin")
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
    #elseif UIKIT
    private static let drawnBy = "The cube is an `MTKView` the gallery registers with "
        + "`StateUIControls.add`, exactly as it registers a view that draws with a layer. A "
        + "view that draws on the GPU is still a `UIView`, so the registration has nothing "
        + "extra to say."
    private static let stopsWith = "The loop also stops with the window, so nothing is "
        + "left turning behind a page you have left."
    #elseif GTK
    private static let drawnBy = "The cube is a `GtkGLArea` drawing with OpenGL 3.3 core, "
        + "held by a `GTKControl` the gallery registers with `StateUIControls.add` - a "
        + "widget like any other, so the registration has nothing extra to say."
    private static let stopsWith = "GTK ticks only a widget on screen, so nothing is "
        + "left turning behind a page you have left."
    #elseif WINUI
    private static let drawnBy = "The cube is a `SwapChainPanel` drawing with Direct3D 11.1, "
        + "made by the gallery's own C++/WinRT relay and held by a `WinUIControl` the gallery "
        + "registers with `StateUIControls.add` - an element like any other, so the "
        + "registration has nothing extra to say."
    private static let stopsWith = "The cube follows WinUI's frames only while it stands on "
        + "screen, so nothing is left turning behind a page you have left."
    #elseif WEB
    private static let drawnBy = "The cube is a custom element of the gallery's own JavaScript, `<gallery-cube3d>`, "
        + "drawing with WebGL 2 and held by a `WebControl` the gallery registers with `StateUIControls.add` - an "
        + "element like any other, so the registration has nothing extra to say."
    private static let stopsWith = "The cube asks for the browser's frames only while it is in view, so nothing is "
        + "left turning behind a page you have left."
    #else
    private static let drawnBy = "The cube is a `TextureView` of the gallery's own Java, drawn into with OpenGL ES "
        + "3.0 from Swift and held by an `AndroidControl` the gallery registers with `StateUIControls.add` - a view "
        + "like any other, so the registration has nothing extra to say."
    private static let stopsWith = "The cube asks for the display's frames only while it stands in a window, so "
        + "nothing is left turning behind a page you have left."
    #endif

    var notes: (any View)? {
        VStack {
            Text(Self.drawnBy)
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The edge is HANDED OVER: `.size($size)` gives the host the state "
                + "itself, and the caption is a conversion of that same journey. Nothing "
                + "here reads `size`, so a drag builds this example not once - the cube "
                + "grows and the number counts up on the host's own frames. The colour "
                + "and the spin are plain values, described again on the one build a "
                + "pick or a flip costs.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Nothing about the drawing crosses. What travels is a number, a "
                + "vocabulary member and a flag; the corners, the matrix and the frames "
                + "are the host's own, and this side never learns they exist.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Turning the spin off stops the host's render loop rather than hiding "
                + "it: the cube holds the angle it had, and a changed size or colour "
                + "still draws the one frame it needs. " + Self.stopsWith)
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("One `Cube3D` on this side, drawn by each host in its own way. An "
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
