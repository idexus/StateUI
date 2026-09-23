// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

/// The context every test's views are made in: the test APK's application.
@MainActor
enum TestContext {
    static var context: JavaObject!
}

/// The smallest complete application around one page: one scene, one window.
struct OneWindowApplication: Application {
    let page: @Sendable () -> any Page

    var scene: any Scene { OneWindow(content: page) }
}

/// The window of a `OneWindowApplication`, its page built again each time the window is.
struct OneWindow: Window {
    let content: @Sendable () -> any Page

    var page: any Page { content() }
}

/// What a handler heard, in order.
final class Received<Value>: Sendable {
    private let received = State(wrappedValue: [Value]())

    var values: [Value] {
        get { received.wrappedValue }
        set { received.wrappedValue = newValue }
    }
}

extension XCTestCase {
    /// Runs `body` as the main actor's: the runner runs every test on the UI thread.
    func onMainActor(_ body: @MainActor () throws -> Void) rethrows {
        try MainActor.assumeIsolated(body)
    }
}

/// The Java a test reads back: where a view stands, and what a group holds.
@MainActor
enum TestJava {
    static let frameLayout = Java.findClass("android/widget/FrameLayout")
    static let newFrameLayout = Java.method(frameLayout, "<init>", "(Landroid/content/Context;)V")
    static let getLeft = Java.method(JavaAPI.view, "getLeft", "()I")
    static let getTop = Java.method(JavaAPI.view, "getTop", "()I")
    static let getWidth = Java.method(JavaAPI.view, "getWidth", "()I")
    static let getHeight = Java.method(JavaAPI.view, "getHeight", "()I")
    static let getChildCount = Java.method(JavaAPI.viewGroup, "getChildCount", "()I")
    static let getTextSize = Java.method(JavaAPI.textView, "getTextSize", "()F")
    static let onEditorAction = Java.method(JavaAPI.textView, "onEditorAction", "(I)V")
    static let editable = Java.findClass("android/text/Editable")
    static let insert = Java.method(editable, "insert", "(ILjava/lang/CharSequence;)Landroid/text/Editable;")
    static let motionEvent = Java.findClass("android/view/MotionEvent")
    static let obtain = Java.staticMethod(motionEvent, "obtain", "(JJIFFI)Landroid/view/MotionEvent;")
    static let recycle = Java.method(motionEvent, "recycle", "()V")
    static let dispatchTouchEvent = Java.method(JavaAPI.view, "dispatchTouchEvent", "(Landroid/view/MotionEvent;)Z")
    static let getTranslationX = Java.method(JavaAPI.view, "getTranslationX", "()F")
    static let getRotation = Java.method(JavaAPI.view, "getRotation", "()F")
    static let getScaleX = Java.method(JavaAPI.view, "getScaleX", "()F")
    static let getScaleY = Java.method(JavaAPI.view, "getScaleY", "()F")
    static let getPivotX = Java.method(JavaAPI.view, "getPivotX", "()F")
    static let getMatrix = Java.method(JavaAPI.view, "getMatrix", "()Landroid/graphics/Matrix;")
    static let matrix = Java.findClass("android/graphics/Matrix")
    static let mapPoints = Java.method(matrix, "mapPoints", "([F)V")
    static let keyEvent = Java.findClass("android/view/KeyEvent")
    static let newKeyEvent = Java.method(keyEvent, "<init>", "(II)V")
    static let dispatchKeyEvent = Java.method(JavaAPI.view, "dispatchKeyEvent", "(Landroid/view/KeyEvent;)Z")

    /// An empty root, as an activity's content is.
    static func root() -> JavaObject {
        Java.new(frameLayout, newFrameLayout, .object(TestContext.context.reference))
    }
}

/// A clock a test winds by hand, in milliseconds.
@MainActor
final class TestClock {
    var now = 0.0
}

extension AndroidRenderer {
    /// A host running the application whose only window shows what `page` builds, at two pixels a point,
    /// on `clock` where one is given.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, _ page: @escaping @Sendable () -> any Page
    ) -> AndroidRenderer {
        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = bare(clock: clock, reducesMotion: reducesMotion)
        renderer.show()
        return renderer
    }

    /// A host with no application yet, whose tree takes what a test applies, at two pixels a point.
    static func bare(clock: TestClock? = nil, reducesMotion: Bool = false) -> AndroidRenderer {
        let renderer = AndroidRenderer(
            context: TestContext.context, root: TestJava.root(), density: 2,
            clock: clock.map { clock in { clock.now } }, reducesMotion: { reducesMotion })
        AndroidRenderer.shared = renderer
        return renderer
    }

    /// Applies `patch` as one whole message, as a render does.
    func apply(_ patch: HostPatch) {
        intake.take(patch, generation: intake.baseline &+ 1) { tree.apply($0, complete: true) }
    }

    /// The view of the element keyed `id`.
    func view(id: ElementId) -> AndroidView? {
        (tree.root?.first(id: id)?.native as? AndroidElement)?.view
    }

    /// One display frame at the clock's time, as the choreographer gives one.
    func frame() {
        displayCycle.frame(now: frameClock.now())
    }

    /// Pumps until `done` holds: a handler resumed on the pool comes back to the UI thread's queue.
    func settle(until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            usleep(10_000)
            pump()
        }
    }

    /// Measures and places the root at `width` by `height` pixels, as a window does.
    func layOut(width: Int32 = 1080, height: Int32 = 1920) {
        Java.call(
            root.reference, JavaAPI.measure,
            .int(ViewConstants.spec(ViewConstants.exactly, width)),
            .int(ViewConstants.spec(ViewConstants.exactly, height)))
        Java.call(root.reference, JavaAPI.layout, .int(0), .int(0), .int(width), .int(height))
    }

    /// Every view of `type` in the mounted tree, depth first.
    func views<Native: AndroidView>(_ type: Native.Type) -> [Native] {
        guard let root = tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: AndroidView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? AndroidElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }
}

extension AndroidView {
    /// Where the view stands in its parent, and its size, in pixels.
    var frame: (x: Int32, y: Int32, width: Int32, height: Int32) {
        (
            Java.callInt(reference, TestJava.getLeft), Java.callInt(reference, TestJava.getTop),
            Java.callInt(reference, TestJava.getWidth), Java.callInt(reference, TestJava.getHeight)
        )
    }

    /// Clicks the view as the user does: its listener runs.
    func click() {
        _ = Java.callBool(reference, JavaAPI.performClick)
    }

    /// Drags a finger across the view's middle, from `start` to `end` of its width, as the user does.
    func drag(from start: Double, to end: Double) {
        let (_, _, width, height) = frame
        let y = Float(height) / 2
        func x(_ fraction: Double) -> Float { Float(Double(width) * fraction) }

        // MotionEvent's ACTION_DOWN, ACTION_MOVE and ACTION_UP, each a little after the one before.
        for (time, action, fraction) in [(0, 0, start), (50, 2, (start + end) / 2), (100, 2, end), (150, 1, end)] {
            let event = Java.callStaticObject(
                TestJava.motionEvent, TestJava.obtain,
                .long(0), .long(Int64(time)), .int(Int32(action)), .float(x(fraction)), .float(y), .int(0))
            _ = Java.callBool(reference, TestJava.dispatchTouchEvent, .object(event))
            Java.call(event!, TestJava.recycle)
            Java.release(local: event)
        }
    }

    /// Where the view's drawing puts `points`, in pixels of its own frame: its transforms applied.
    func drawn(_ points: [(Float, Float)]) -> [(Float, Float)] {
        let flat = points.flatMap { [$0.0, $0.1] }
        let array = Java.jni.NewFloatArray(Java.env, jsize(flat.count))
        flat.withUnsafeBufferPointer { Java.jni.SetFloatArrayRegion(Java.env, array, 0, jsize(flat.count), $0.baseAddress) }
        let matrix = Java.callObject(reference, TestJava.getMatrix)
        Java.call(matrix!, TestJava.mapPoints, .object(array))

        var mapped = [Float](repeating: 0, count: flat.count)
        mapped.withUnsafeMutableBufferPointer { Java.jni.GetFloatArrayRegion(Java.env, array, 0, jsize(flat.count), $0.baseAddress) }
        Java.release(local: matrix)
        Java.release(local: array)
        return stride(from: 0, to: mapped.count, by: 2).map { (mapped[$0], mapped[$0 + 1]) }
    }

    /// Presses and lets go of the hardware key `code`, as a keyboard does.
    func press(key code: Int32) {
        for action: Int32 in [0, 1] {
            let event = Java.new(TestJava.keyEvent, TestJava.newKeyEvent, .int(action), .int(code))
            withExtendedLifetime(event) {
                _ = Java.callBool(reference, TestJava.dispatchKeyEvent, .object(event.reference))
            }
        }
    }
}

extension AndroidTextFieldView {
    /// Types `text` at the caret, as a keyboard does.
    func type(_ text: String) {
        let editable = Java.callObject(reference, JavaAPI.getText)!
        let words = Java.string(text)
        let caret = Java.callInt(reference, JavaAPI.getSelectionStart)
        Java.release(local: Java.callObject(editable, TestJava.insert, .int(caret), .object(words)))
        Java.release(local: words)
        Java.release(local: editable)
    }

    /// Where the caret stands, in UTF-16 units.
    var caret: Int32 { Java.callInt(reference, JavaAPI.getSelectionStart) }
}
