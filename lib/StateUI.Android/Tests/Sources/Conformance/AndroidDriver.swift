// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// The Android Views host as the conformance suite drives it: each user's act through the listener or the event the
/// platform's own input takes into the host, and each read from the view itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class AndroidDriver: HostDriver {
    let host = "Android Views"
    let cannot: [String: String] = [:]

    /// What the families ask of a driver that Android's has no path for yet says so, and stays empty in Android's
    /// column with why, rather than failing.
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "Android's driver has no path for it yet"
    }

    /// The host the driver started last.
    private(set) var renderer: AndroidRenderer?

    var register: HostRegister { AndroidRealization.register }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        finish()
        stateUIUseApp(OneWindowApplication(page: page))
        let window = TestContext.window!
        let root = Java.new(TestJava.frameLayout, TestJava.newFrameLayout, .object(window.reference))
        let renderer = AndroidRenderer(
            context: window, root: root, density: 2, clock: clock.map { clock in { clock.now } },
            reducesMotion: { reducesMotion })
        AndroidRenderer.shared = renderer
        self.renderer = renderer
        Java.call(window.reference, Self.setContentView, .object(root.reference))
        renderer.show()
        layOut()
        // The activity comes to the front: onResume.
        renderer.setPhase(.active)
        return renderer.runtime.tree
    }

    /// Lays the root out in the room its window gives it, and tells the host so, as the window's traversal does - at
    /// once, so a case acts on what it shows and reads what a frame changed without waiting for the display's next.
    /// Design: docs/design/platforms/android/conformance.md#layout
    private func layOut() {
        guard let renderer else { return }
        // A root just shown stands at no size until the window's traversal: its window's content frame gives it.
        let frame = Java.callObject(renderer.root.reference, Self.getParent)
        let room = frame ?? renderer.root.reference
        let width = Java.callInt(room, TestJava.getWidth)
        let height = Java.callInt(room, TestJava.getHeight)
        Java.release(local: frame)
        if width > 0, height > 0 { renderer.layOut(width: width, height: height) }
        renderer.runtime.frames.laidOut()
    }

    /// Lets the last host's tree go - the questions it put over the window, the keyboard and the focus with it - as
    /// an activity's end does: each case starts in a window as a new activity's.
    func finish() {
        Java.callStatic(Self.dialogs, Self.dismissAll)
        if let root = renderer?.root.reference {
            _ = Java.callStaticBool(JavaAPI.environment, JavaAPI.hideKeyboard, .object(root))
            Java.call(root, Self.clearFocus)
        }
        renderer?.runtime.tree.root?.leave()
        renderer = nil
    }

    func step() {
        guard let renderer else { return }
        Self.runLooper(10)
        renderer.runtime.pump.turn()
        layOut()
        if renderer.frameClock.held { renderer.frame() }
    }

    func turn() {
        renderer?.runtime.pump.turn()
    }

    func frame() {
        renderer?.frame()
        layOut()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? AndroidElement)?.view
        switch (act, view) {
        case (.activate, let button as AndroidButtonView): button.click()
        case (.toggle, let toggle as AndroidToggleView): toggle.click()
        case (.type(let words), let field as AndroidTextFieldView): Self.type(words, into: field)
        case (.submit, let field as AndroidTextFieldView):
            // The keyboard's own action, as the field's return key says it: done, or search for a search field.
            Java.call(field.reference, Self.onEditorAction, .int(element.type == .searchField ? 3 : 6))
        case (.answer(let caption, let words), _):
            let answered = Java.frame {
                Java.callStaticBool(
                    Self.dialogs, Self.answer, .object(Java.string(caption)), .object(words.flatMap(Java.string)))
            }
            guard answered else { throw DriverCannot("answer by \(caption)") }
        case (.switchAway, _) where element.type == .window: renderer?.setPhase(.inactive)
        case (.switchBack, _) where element.type == .window: renderer?.setPhase(.active)
        case (.minimize, _) where element.type == .window:
            renderer?.setPhase(.inactive)
            renderer?.setPhase(.background)
        case (.restore, _) where element.type == .window: renderer?.setPhase(.active)
        case (.close, _) where element.type == .window:
            renderer?.setPhase(.inactive)
            renderer?.setPhase(.background)
            renderer?.destroying()
        default: throw DriverCannot(act, on: element)
        }
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        let view = (element.native as? AndroidElement)?.view
        switch (property, view) {
        case (.isOn, let toggle as AndroidToggleView): return toggle.isOn.propValue
        case (.value, let slider as AndroidSliderView): return slider.value.propValue
        case (.minimum, let slider as AndroidSliderView): return slider.minimum.propValue
        case (.maximum, let slider as AndroidSliderView): return slider.maximum.propValue
        case (.value, let stepper as AndroidStepperView): return stepper.value.propValue
        case (.progress, let bar as AndroidProgressBarView): return bar.progress.propValue
        case (.isRunning, let spinner as AndroidActivityIndicatorView): return spinner.isRunning.propValue
        case (.text, let text as AndroidTextView): return text.text.propValue
        case (.isVisible, let view?): return (Java.callInt(view.reference, JavaAPI.getVisibility) == 0).propValue
        case (.opacity, let view?): return Double(Java.callFloat(view.reference, Self.getAlpha)).propValue
        case (.isEnabled, let view?): return Java.callBool(view.reference, Self.isEnabled).propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// Runs the UI thread's own messages for `millis` milliseconds: a web page's client, a choreographer's frame, a
    /// posted callback arrive as they do in an application.
    /// Design: docs/design/platforms/android/conformance.md#the-ui-threads-messages
    private static func runLooper(_ millis: Int64) {
        Java.callStatic(looper, runLooperFor, .long(millis))
    }

    func question(over element: MountedElement) throws -> Question? {
        let words = Java.frame { () -> [String?]? in
            guard let asked = Java.callStaticObject(Self.dialogs, Self.question) else { return nil }
            let count = Java.jni.GetArrayLength(Java.env, asked)
            return (0..<count).map { index in
                Java.jni.GetObjectArrayElement(Java.env, asked, index).map { Java.text($0) }
            }
        }
        guard let words, words.count >= 3 else { return nil }
        return Question(
            title: words[0] ?? "", message: words[1] ?? "", buttons: words.dropFirst(3).compactMap { $0 },
            field: words[2])
    }

    func focused(_ element: MountedElement) throws -> Bool {
        guard let view = (element.native as? AndroidElement)?.view else {
            throw DriverCannot("read the focus of \(element.type.name)")
        }
        return Java.callBool(view.reference, TestJava.hasFocus)
    }

    /// Types `words` as the whole of a field's words, as the keyboard edits them: the field's own words replaced in
    /// its editable text, which its watcher hears as it hears a key.
    private static func type(_ words: String, into field: AndroidTextFieldView) {
        let editable = Java.callObject(field.reference, JavaAPI.getText)!
        let text = Java.string(words)
        let length = Java.callInt(editable, length)
        Java.release(local: Java.callObject(editable, replace, .int(0), .int(length), .object(text)))
        Java.release(local: text)
        Java.release(local: editable)
    }

    private static let clearFocus = Java.method(JavaAPI.view, "clearFocus", "()V")
    private static let getParent = Java.method(JavaAPI.view, "getParent", "()Landroid/view/ViewParent;")
    private static let dialogs = Java.findClass("stateui/android/StateUIDialogs")
    private static let question = Java.staticMethod(dialogs, "question", "()[Ljava/lang/String;")
    private static let answer = Java.staticMethod(
        dialogs, "answer", "(Ljava/lang/String;Ljava/lang/String;)Z")
    private static let dismissAll = Java.staticMethod(dialogs, "dismissAll", "()V")
    private static let setContentView = Java.method(
        Java.findClass("android/app/Activity"), "setContentView", "(Landroid/view/View;)V")
    private static let looper = Java.findClass("stateui/android/test/TestLooper")
    private static let runLooperFor = Java.staticMethod(looper, "run", "(J)V")
    private static let editable = Java.findClass("android/text/Editable")
    private static let replace = Java.method(
        editable, "replace", "(IILjava/lang/CharSequence;)Landroid/text/Editable;")
    private static let length = Java.method(Java.findClass("java/lang/CharSequence"), "length", "()I")
    private static let onEditorAction = Java.method(JavaAPI.textView, "onEditorAction", "(I)V")
    private static let getAlpha = Java.method(JavaAPI.view, "getAlpha", "()F")
    private static let isEnabled = Java.method(JavaAPI.view, "isEnabled", "()Z")
}
