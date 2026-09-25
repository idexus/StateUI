// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Epoxy loads each GL function into a global pointer of its own, which GTK has made current before any call here.
@preconcurrency import CGalleryOpenGL
import CStateUIGTK
import GalleryUI
import StateUIGTK

/// A cube drawn by OpenGL 3.3 core in a `GtkGLArea`, turning on the widget's frame clock - a widget that knows
/// nothing of StateUI. The Swift half is Sources/Samples/Interop/Cube3D.swift.
@MainActor
final class OpenGLCube3DWidget: GTKControl {
    let widget: UnsafeMutablePointer<GtkWidget>

    /// How long the cube's edge is, as a share of the area.
    var cubeSize = 0.6 {
        didSet { if cubeSize != oldValue { gtk_gl_area_queue_render(area) } }
    }

    /// Which colour it is painted.
    var color = CubeColor.teal {
        didSet { if color != oldValue { gtk_gl_area_queue_render(area) } }
    }

    /// Whether it turns. Stopped, it holds the angle it had.
    var isSpinning = true {
        didSet { if isSpinning != oldValue { followClock() } }
    }

    private static let colors: [(Float, Float, Float)] = [(0.161, 0.722, 0.678), (0.961, 0.710, 0.275), (0.580, 0.443, 0.929)]

    /// Six faces of two triangles each, every corner its position and its face's brightness in w.
    private static let corners: [Float] = {
        let faces: [([(Float, Float, Float)], Float)] = [
            ([(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)], 1.00),
            ([(-1, -1, -1), (-1, 1, -1), (-1, 1, 1), (-1, -1, 1)], 0.55),
            ([(-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)], 0.88),
            ([(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)], 0.42),
            ([(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)], 0.97),
            ([(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1)], 0.50),
        ]
        return faces.flatMap { corners, shade in
            [0, 1, 2, 0, 2, 3].flatMap { [corners[$0].0, corners[$0].1, corners[$0].2, shade] }
        }
    }()

    private static let vertexShader = """
        #version 330 core
        layout(location = 0) in vec4 corner;
        uniform mat4 transform;
        uniform vec4 color;
        out vec4 painted;
        void main() {
            gl_Position = transform * vec4(corner.xyz, 1.0);
            painted = vec4(color.rgb * corner.w, color.a);
        }
        """

    private static let fragmentShader = """
        #version 330 core
        in vec4 painted;
        out vec4 fragment;
        void main() { fragment = painted; }
        """

    private var area: UnsafeMutablePointer<GtkGLArea> { UnsafeMutablePointer<GtkGLArea>(OpaquePointer(widget)) }
    private var program: GLuint = 0
    private var vertexArray: GLuint = 0
    private var buffer: GLuint = 0
    private var transformAt: GLint = -1
    private var colorAt: GLint = -1

    /// The angle turned, and the frame clock's time of the last frame it turned on - 0 for none yet.
    private var angle = 0.0
    private var lastFrame = 0
    private var tick: guint = 0

    /// An area asking GTK for OpenGL 3.3 core with a depth buffer, its GL made where the widget is realized.
    init() {
        widget = gtk_gl_area_new()
        g_object_ref_sink(widget)
        gtk_widget_set_size_request(widget, 240, 240)
        gtk_gl_area_set_required_version(area, 3, 3)
        gtk_gl_area_set_allowed_apis(area, GDK_GL_API_GL)
        gtk_gl_area_set_has_depth_buffer(area, 1)

        // Each a C callback, handed the area as its data: it lives as long as its widget.
        let me = Unmanaged.passUnretained(self).toOpaque()
        let realized: @convention(c) (OpaquePointer?, gpointer?) -> Void = { _, data in
            MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).realize() }
        }
        let unrealized: @convention(c) (OpaquePointer?, gpointer?) -> Void = { _, data in
            MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).unrealize() }
        }
        let render: @convention(c) (OpaquePointer?, OpaquePointer?, gpointer?) -> gboolean = { _, _, data in
            MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).render() }
        }
        let mapped: @convention(c) (OpaquePointer?, gpointer?) -> Void = { _, data in
            MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).lastFrame = 0 }
        }
        for (signal, handler) in [
            ("realize", unsafeBitCast(realized, to: GCallback.self)),
            ("unrealize", unsafeBitCast(unrealized, to: GCallback.self)),
            ("render", unsafeBitCast(render, to: GCallback.self)),
            ("map", unsafeBitCast(mapped, to: GCallback.self)),
        ] {
            g_signal_connect_data(UnsafeMutableRawPointer(widget), signal, handler, me, nil, GConnectFlags(0))
        }
        followClock()
    }

    isolated deinit {
        if tick != 0 { gtk_widget_remove_tick_callback(widget, tick) }
        g_signal_handlers_disconnect_matched(
            UnsafeMutableRawPointer(widget), G_SIGNAL_MATCH_DATA, 0, 0, nil, nil,
            Unmanaged.passUnretained(self).toOpaque())
        g_object_unref(widget)
    }

    private static func from(_ data: gpointer?) -> OpenGLCube3DWidget {
        Unmanaged<OpenGLCube3DWidget>.fromOpaque(data!).takeUnretainedValue()
    }

    /// Turns on the widget's frames while spinning: GTK ticks only a mapped widget, so the cube stops behind a page
    /// the user has left. A stopped cube still owes one frame to a value that changed.
    private func followClock() {
        if isSpinning, tick == 0 {
            lastFrame = 0
            let turn: @convention(c) (UnsafeMutablePointer<GtkWidget>?, OpaquePointer?, gpointer?) -> gboolean = {
                _, clock, data in
                nonisolated(unsafe) let clock = clock
                return MainActor.assumeIsolated { OpenGLCube3DWidget.from(data).turn(at: gdk_frame_clock_get_frame_time(clock)) }
            }
            tick = gtk_widget_add_tick_callback(widget, turn, Unmanaged.passUnretained(self).toOpaque(), nil)
        } else if !isSpinning, tick != 0 {
            gtk_widget_remove_tick_callback(widget, tick)
            tick = 0
        }
    }

    /// One frame of turning: the angle moves by the time since the last, in seconds.
    private func turn(at time: Int) -> gboolean {
        if lastFrame != 0 { angle += Double(time - lastFrame) / 1_000_000 }
        lastFrame = time
        gtk_gl_area_queue_render(area)
        return 1
    }

    /// The shaders, the corners and where the uniforms stand, made in the area's own context.
    private func realize() {
        gtk_gl_area_make_current(area)
        guard gtk_gl_area_get_error(area) == nil else { return }

        program = epoxy_glCreateProgram()
        for (kind, source) in [(GL_VERTEX_SHADER, Self.vertexShader), (GL_FRAGMENT_SHADER, Self.fragmentShader)] {
            let shader = epoxy_glCreateShader(GLenum(kind))
            source.withCString { text in
                var lines: UnsafePointer<GLchar>? = text
                epoxy_glShaderSource(shader, 1, &lines, nil)
            }
            epoxy_glCompileShader(shader)
            epoxy_glAttachShader(program, shader)
            epoxy_glDeleteShader(shader)
        }
        epoxy_glLinkProgram(program)
        transformAt = epoxy_glGetUniformLocation(program, "transform")
        colorAt = epoxy_glGetUniformLocation(program, "color")

        epoxy_glGenVertexArrays(1, &vertexArray)
        epoxy_glBindVertexArray(vertexArray)
        epoxy_glGenBuffers(1, &buffer)
        epoxy_glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
        Self.corners.withUnsafeBytes { bytes in
            epoxy_glBufferData(GLenum(GL_ARRAY_BUFFER), bytes.count, bytes.baseAddress, GLenum(GL_STATIC_DRAW))
        }
        epoxy_glEnableVertexAttribArray(0)
        epoxy_glVertexAttribPointer(0, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 16, nil)
    }

    private func unrealize() {
        gtk_gl_area_make_current(area)
        guard gtk_gl_area_get_error(area) == nil else { return }
        epoxy_glDeleteBuffers(1, &buffer)
        epoxy_glDeleteVertexArrays(1, &vertexArray)
        epoxy_glDeleteProgram(program)
    }

    /// Clears to the housing's colour and draws the cube: turned, scaled and seen in perspective.
    private func render() -> gboolean {
        epoxy_glClearColor(0.102, 0.090, 0.145, 1)
        epoxy_glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        guard program != 0 else { return 1 }

        epoxy_glEnable(GLenum(GL_DEPTH_TEST))
        epoxy_glUseProgram(program)
        let width = Double(max(gtk_widget_get_width(widget), 1))
        let height = Double(max(gtk_widget_get_height(widget), 1))
        var transform = Self.transform(aspect: width / height, turn: angle, scale: min(max(cubeSize, 0), 1))
        epoxy_glUniformMatrix4fv(transformAt, 1, GLboolean(GL_FALSE), &transform)
        let (red, green, blue) = Self.colors[Int(color.rawValue)]
        epoxy_glUniform4f(colorAt, red, green, blue, 1)
        epoxy_glBindVertexArray(vertexArray)
        epoxy_glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(Self.corners.count / 4))
        return 1
    }

    // MARK: - The arithmetic behind the matrix, column by column

    private static func transform(aspect: Double, turn: Double, scale: Double) -> [Float] {
        multiply(
            perspective(fieldOfView: 50 * .pi / 180, aspect: aspect),
            multiply(translation(z: -4),
                     multiply(rotation(x: turn * 0.35), multiply(rotation(y: turn * 0.60), scaling(scale)))))
    }

    private static func perspective(fieldOfView: Double, aspect: Double) -> [Float] {
        let focal = 1 / tan(fieldOfView / 2)
        let (near, far) = (0.1, 100.0)
        var matrix = [Float](repeating: 0, count: 16)
        matrix[0] = Float(focal / aspect)
        matrix[5] = Float(focal)
        matrix[10] = Float((far + near) / (near - far))
        matrix[11] = -1
        matrix[14] = Float(2 * far * near / (near - far))
        return matrix
    }

    private static func identity() -> [Float] {
        [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    }

    private static func translation(z: Double) -> [Float] {
        var matrix = identity()
        matrix[14] = Float(z)
        return matrix
    }

    private static func rotation(x angle: Double) -> [Float] {
        var matrix = identity()
        (matrix[5], matrix[6], matrix[9], matrix[10]) = (Float(cos(angle)), Float(sin(angle)), Float(-sin(angle)), Float(cos(angle)))
        return matrix
    }

    private static func rotation(y angle: Double) -> [Float] {
        var matrix = identity()
        (matrix[0], matrix[2], matrix[8], matrix[10]) = (Float(cos(angle)), Float(-sin(angle)), Float(sin(angle)), Float(cos(angle)))
        return matrix
    }

    private static func scaling(_ scale: Double) -> [Float] {
        var matrix = identity()
        (matrix[0], matrix[5], matrix[10]) = (Float(scale), Float(scale), Float(scale))
        return matrix
    }

    private static func multiply(_ left: [Float], _ right: [Float]) -> [Float] {
        (0..<16).map { at in
            let (column, row) = (at / 4, at % 4)
            return (0..<4).reduce(Float(0)) { sum, step in sum + left[step * 4 + row] * right[column * 4 + step] }
        }
    }
}

// MARK: - Registration

extension OpenGLCube3DWidget {
    /// Adds the cube for `Cube3DContract`. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIControls.add(Cube3DContract.self, create: { _ in OpenGLCube3DWidget() }) { cube in
            cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
            cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
            cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
        }
    }
}
