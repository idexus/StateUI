// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CGalleryGLES
import GalleryUI
import StateUIAndroid

// listing: Cube3DSample.Android.swift
/// A cube drawn with OpenGL ES 3.0 into the surface of the gallery's own Java view, com.stateui.gallery.Cube3DView -
/// a TextureView that asks for the display's frames while the cube spins and stands in a window. The Swift half is
/// Sources/Samples/Interop/Cube3D.swift.
@MainActor
final class GLESCube3DView: AndroidControl {
    let view: JavaObject

    /// How long the cube's edge is, as a share of the view.
    var cubeSize = 0.6 {
        didSet { if cubeSize != oldValue { draw() } }
    }

    /// Which colour it is painted.
    var color = CubeColor.teal {
        didSet { if color != oldValue { draw() } }
    }

    /// Whether it turns. Stopped, it holds the angle it had.
    var isSpinning = true {
        didSet { if isSpinning != oldValue { Java.call(view.reference, Self.setSpinning, .bool(isSpinning)) } }
    }

    private let number: Int64

    /// The surface drawn into, while the view has one: its window, the EGL objects over it, its size in pixels.
    private var drawing: Drawing?

    /// The angle turned, and the display's time of the frame it last turned on - 0 for none yet.
    private var angle = 0.0
    private var lastFrame: Int64 = 0

    private static let viewClass = Java.findClass("com/stateui/gallery/Cube3DView")
    private static let make = Java.method(viewClass, "<init>", "(Landroid/content/Context;J)V")
    private static let setSpinning = Java.method(viewClass, "setSpinning", "(Z)V")

    init() {
        number = GalleryControls.reserve()
        view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
        GalleryControls.hold(self, as: number)
    }

    isolated deinit {
        drawing?.close()
        GalleryControls.forget(number)
    }

    /// The view's surface came, or changed size: the EGL context and the cube's program are made the first time.
    func surfaceReady(_ surface: jobject?, environment: UnsafeMutablePointer<JNIEnv?>?, width: Int32, height: Int32) {
        if drawing == nil, let surface, let window = ANativeWindow_fromSurface(environment, surface) {
            drawing = Drawing(window: window)
        }
        drawing?.size = (width, height)
        lastFrame = 0
        draw()
    }

    /// The view's surface is going: nothing is drawn into it again.
    func surfaceGone() {
        drawing?.close()
        drawing = nil
    }

    /// One display frame while spinning: the angle moves by the time since the last, in seconds.
    func frame(at time: Int64) {
        if lastFrame != 0 { angle += Double(time - lastFrame) / 1_000_000_000 }
        lastFrame = time
        draw()
    }
    // listing: end

    /// Draws the cube as it stands: turned, scaled and seen in perspective, over the housing's colour.
    private func draw() {
        drawing?.draw(
            transform: Self.transform(aspect: drawing?.aspect ?? 1, turn: angle, scale: min(max(cubeSize, 0), 1)),
            color: Self.colors[Int(color.rawValue)])
    }

    private static let colors: [(Float, Float, Float)] = [(0.161, 0.722, 0.678), (0.961, 0.710, 0.275), (0.580, 0.443, 0.929)]

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
// listing: Cube3DSample.Android.swift
}
// listing: end

extension GLESCube3DView {
    /// A window of the view's surface and what OpenGL ES draws into it: the display, the context, the surface over
    /// the window, the cube's program and corners.
    @MainActor
    final class Drawing {
        var size: (width: Int32, height: Int32) = (1, 1)
        var aspect: Double { Double(max(size.width, 1)) / Double(max(size.height, 1)) }

        private let window: OpaquePointer
        private let display: EGLDisplay?
        private var context: EGLContext?
        private var surface: EGLSurface?
        private var program: GLuint = 0
        private var vertexArray: GLuint = 0
        private var buffer: GLuint = 0
        private var transformAt: GLint = -1
        private var colorAt: GLint = -1

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
            #version 300 es
            // listing: Cube3DSample.Android.glsl
            // The vertex shader, compiled for OpenGL ES 3.0: a corner carries its face's brightness in w, and the
            // colour is the frame's.
            layout(location = 0) in vec4 corner;
            uniform mat4 transform;
            uniform vec4 color;
            out vec4 painted;
            void main() {
                gl_Position = transform * vec4(corner.xyz, 1.0);
                painted = vec4(color.rgb * corner.w, color.a);
            }
            // listing: end
            """

        private static let fragmentShader = """
            #version 300 es
            // listing: Cube3DSample.Android.glsl
            // The fragment shader: every point of a face takes the colour its corners were painted.
            precision mediump float;
            in vec4 painted;
            out vec4 fragment;
            void main() { fragment = painted; }
            // listing: end
            """

        /// An OpenGL ES 3.0 context with a depth buffer over `window`, the cube's program and corners made in it.
        init(window: OpaquePointer) {
            self.window = window
            display = eglGetDisplay(nil)
            eglInitialize(display, nil, nil)

            let wanted: [EGLint] = [
                EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT, EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RED_SIZE, 8,
                EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_DEPTH_SIZE, 16, EGL_NONE,
            ]
            var config: EGLConfig?
            var count: EGLint = 0
            guard eglChooseConfig(display, wanted, &config, 1, &count) != 0, count > 0 else { return }

            let version: [EGLint] = [EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE]
            context = eglCreateContext(display, config, nil, version)
            surface = eglCreateWindowSurface(display, config, window, nil)
            guard context != nil, surface != nil, eglMakeCurrent(display, surface, surface, context) != 0 else { return }

            program = glCreateProgram()
            for (kind, source) in [(GL_VERTEX_SHADER, Self.vertexShader), (GL_FRAGMENT_SHADER, Self.fragmentShader)] {
                let shader = glCreateShader(GLenum(kind))
                source.withCString { text in
                    var lines: UnsafePointer<GLchar>? = text
                    glShaderSource(shader, 1, &lines, nil)
                }
                glCompileShader(shader)
                glAttachShader(program, shader)
                glDeleteShader(shader)
            }
            glLinkProgram(program)
            transformAt = glGetUniformLocation(program, "transform")
            colorAt = glGetUniformLocation(program, "color")

            glGenVertexArrays(1, &vertexArray)
            glBindVertexArray(vertexArray)
            glGenBuffers(1, &buffer)
            glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
            Self.corners.withUnsafeBytes { bytes in
                glBufferData(GLenum(GL_ARRAY_BUFFER), bytes.count, bytes.baseAddress, GLenum(GL_STATIC_DRAW))
            }
            glEnableVertexAttribArray(0)
            glVertexAttribPointer(0, 4, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 16, nil)
        }

        /// Clears to the housing's colour, draws the cube by `transform` in `color`, and shows the frame.
        func draw(transform: [Float], color: (Float, Float, Float)) {
            guard program != 0, eglMakeCurrent(display, surface, surface, context) != 0 else { return }

            glViewport(0, 0, size.width, size.height)
            glClearColor(0.102, 0.090, 0.145, 1)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
            glEnable(GLenum(GL_DEPTH_TEST))
            glUseProgram(program)
            var matrix = transform
            glUniformMatrix4fv(transformAt, 1, GLboolean(GL_FALSE), &matrix)
            glUniform4f(colorAt, color.0, color.1, color.2, 1)
            glBindVertexArray(vertexArray)
            glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(Self.corners.count / 4))
            eglSwapBuffers(display, surface)
        }

        /// Lets go of everything drawn with and of the window: nothing is drawn into the surface after.
        func close() {
            if program != 0, eglMakeCurrent(display, surface, surface, context) != 0 {
                glDeleteBuffers(1, &buffer)
                glDeleteVertexArrays(1, &vertexArray)
                glDeleteProgram(program)
                program = 0
            }
            eglMakeCurrent(display, nil, nil, nil)
            if let surface { eglDestroySurface(display, surface) }
            if let context { eglDestroyContext(display, context) }
            surface = nil
            context = nil
            ANativeWindow_release(window)
        }
    }
}

// listing: Cube3DSample.Android.swift
extension GLESCube3DView {
    /// Adds the cube for `Cube3DContract`. Said once, as the library loads.
    @MainActor
    static func register() {
        StateUIControls.add(Cube3DContract.self, create: { _ in GLESCube3DView() }) { cube in
            cube.property(Cube3DContract.size) { control, size in control.cubeSize = size ?? 0.6 }
            cube.property(Cube3DContract.color) { control, color in control.color = color ?? .teal }
            cube.property(Cube3DContract.isSpinning) { control, spinning in control.isSpinning = spinning ?? true }
        }
    }
}
// listing: end
