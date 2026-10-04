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
    let platformHasNone = AndroidDriver.none()

    /// What Android holds none of: what StateUI draws in its own views' `onDraw` and drawables, where StateUI's
    /// layout places the children, what StateUI measures and what the host cuts - each proven by its effect in
    /// another case.
    private static func none() -> [String: String] {
        var none = [
            "read growsWithText of TextEditor":
                "an editor's growing is StateUI's measuring, which no property of Android's holds; its frames prove it",
        ]
        for field in ["TextField", "SearchField", "TextEditor"] {
            none["read maximumLength of \(field)"] =
                "Android's field keeps no bound of StateUI's: the host cuts what is typed, and typing proves it"
        }
        let shapePaint = [
            "contentMode", "geometryTransform", "fill", "stroke", "lineWidth", "dashPhase", "dash",
            "lineCap", "lineJoin", "miterLimit",
        ]
        for shape in ["Ellipse", "Line", "Path", "Polygon", "Polyline", "Rectangle"] {
            for member in shapePaint {
                none["read \(member) of \(shape)"] =
                    "StateUI draws a shape in its view's onDraw, which holds none of its \(member); its drawing proves it"
            }
        }
        for layout in ["Grid", "HStack", "VStack", "ZStack", "ScrollView"] {
            for member in ["stroke", "lineWidth", "shape"] {
                none["read \(member) of \(layout)"] =
                    "StateUI draws a layout's box in a drawable of its own, which holds none of its \(member); its drawing proves it"
            }
            none["read padding of \(layout)"] =
                "Android's view group places its children where StateUI's layout says; their frames prove it"
        }
        for stack in ["HStack", "VStack"] {
            none["read spacing of \(stack)"] =
                "Android's view group places its children where StateUI's layout says; their frames prove it"
        }
        return none
    }

    /// What the families ask of a driver that Android's has no path for yet says so, and stays empty in Android's
    /// column with why, rather than failing.
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "Android's driver has no path for it yet"
    }

    /// The host the driver started last.
    private(set) var renderer: AndroidRenderer?

    /// What the hosts wrote to their log since the last one started.
    private let written = AndroidLogLines()

    var register: HostRegister { AndroidRealization.register }

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @Sendable () -> any View
    ) -> MountedTree {
        finish()
        written.listen()
        stateUIUseApp(OneWindowApplication(page: page))
        let window = TestContext.window!
        let root = Java.new(TestJava.frameLayout, TestJava.newFrameLayout, .object(window.reference))
        let renderer = AndroidRenderer(
            context: window, root: root, density: 2, clock: clock.map { clock in { clock.now } },
            reducesMotion: { reducesMotion })
        AndroidRenderer.shared = renderer
        self.renderer = renderer
        Java.call(window.reference, Self.setContentView, .object(root.reference))
        Java.callStatic(Self.testPixels, Self.paintNothing, .object(window.reference))
        AndroidPersistence.writeScenes("", context: window.reference)  // no scenes an earlier case kept
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

    /// What the hosts wrote to their log since the driver last started one.
    func logged() throws -> [String] {
        written.lines
    }

    var liveViews: Int? {
        AndroidView.liveCount
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

    /// The colour the window shows at `point` of the view, as the user sees it (`TestPixels.color`); nil where the
    /// view draws nothing there.
    func color(of element: MountedElement, at point: Point) throws -> Color? {
        guard let view = (element.native as? AndroidElement)?.view else {
            throw DriverCannot("read the colour of \(element.type.name)")
        }
        let argb = UInt32(bitPattern: Java.callStaticInt(
            Self.testPixels, Self.pixel, .object(view.reference), .int(Int32(point.x * 2)), .int(Int32(point.y * 2))))
        guard argb >> 24 > 0x80 else { return nil }
        return Self.color(argb | 0xFF00_0000)
    }

    /// Where the element's view stands in its window, as Android placed it.
    func place(of element: MountedElement) throws -> Rect {
        guard let view = (element.native as? AndroidElement)?.layoutItem?.view else {
            throw DriverCannot("read where \(element.type.name) stands")
        }
        let (corner, size) = (view.cornerInWindow, view.frame)
        return Rect(
            x: corner.x, y: corner.y, width: Double(size.width) / view.density, height: Double(size.height) / view.density)
    }

    func focused(_ element: MountedElement) throws -> Bool {
        guard let view = (element.native as? AndroidElement)?.view else {
            throw DriverCannot("read the focus of \(element.type.name)")
        }
        return Java.callBool(view.reference, TestJava.hasFocus)
    }

    static let clearFocus = Java.method(JavaAPI.view, "clearFocus", "()V")
    static let getParent = Java.method(JavaAPI.view, "getParent", "()Landroid/view/ViewParent;")
    static let dialogs = Java.findClass("stateui/android/StateUIDialogs")
    static let question = Java.staticMethod(dialogs, "question", "()[Ljava/lang/String;")
    static let answer = Java.staticMethod(
        dialogs, "answer", "(Ljava/lang/String;Ljava/lang/String;)Z")
    static let dismissAll = Java.staticMethod(dialogs, "dismissAll", "()V")
    static let setContentView = Java.method(
        Java.findClass("android/app/Activity"), "setContentView", "(Landroid/view/View;)V")
    static let looper = Java.findClass("stateui/android/test/TestLooper")
    static let runLooperFor = Java.staticMethod(looper, "run", "(J)V")
    static let length = Java.method(Java.findClass("java/lang/CharSequence"), "length", "()I")
    static let onEditorAction = Java.method(JavaAPI.textView, "onEditorAction", "(I)V")
    static let getAlpha = Java.method(JavaAPI.view, "getAlpha", "()F")
    static let isEnabled = Java.method(JavaAPI.view, "isEnabled", "()Z")
}

/// The host's log, line by line, as the driver hears it - and logcat still.
final class AndroidLogLines: @unchecked Sendable {
    private(set) var lines: [String] = []

    /// Listens to the host's log from now on.
    @MainActor func listen() {
        lines = []
        AndroidRenderer.log = HostLog(host: "Android") { [self] line in
            lines.append(line)
            AndroidStandardStreams.log(line)
        }
    }
}
