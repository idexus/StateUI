// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

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

/// A clock a test winds by hand, in milliseconds.
@MainActor
final class TestClock {
    var now = 0.0
}

/// The test thread as WinUI's: WinUI embedded in it once, since no loop of WinUI's runs a test.
enum WinUITestHost {
    /// Makes the test thread hold WinUI elements, once, the tests' own pictures the application's.
    static func embed() {
        var callbacks = WinUICallbacks.table
        precondition(stateui_winui_embed(&callbacks) == 0, "WinUI could not stand on the test thread")
        stateui_winui_set_pictures(pictures)
    }

    /// Tests/Resources/Images, beside this file's folder.
    static let pictures: String = {
        var path = #filePath
        for _ in 0..<2 { path = String(path[..<(path.lastIndex { $0 == "\\" || $0 == "/" } ?? path.endIndex)]) }
        return path + "/Resources/Images"
    }()

    /// Runs the thread's messages for `seconds`: a window's first frame, and the layout WinUI asks for.
    static func pump(_ seconds: Double = 0.2) {
        stateui_winui_pump(seconds)
    }

    /// The window a bare host's root stands in, made once.
    @MainActor static let window = WinUIWindow()
}

extension XCTestCase {
    /// Runs `body` as the main actor's on the test thread, which holds WinUI: a drain makes it MainActor's first.
    func onUIThread<Result: Sendable>(_ body: @MainActor () throws -> Result) rethrows -> Result {
        WinUITestHost.embed()
        _ = CoreLink().runJobs()
        return try MainActor.assumeIsolated(body)
    }
}

extension WinUIRenderer {
    /// A host showing `page` in a window of its own, laid out, on `clock` where one is given.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, _ page: @escaping @Sendable () -> any Page
    ) -> WinUIRenderer {
        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = replacing(clock: clock, reducesMotion: reducesMotion)
        renderer.show()
        WinUITestHost.pump()
        return renderer
    }

    /// A host whose tree takes only what a test applies; its root stands in the test's window. The core's own
    /// render is taken and set aside, so no frame renders the core's tree over the test's.
    static func bare(clock: TestClock? = nil, reducesMotion: Bool = false) -> WinUIRenderer {
        let renderer = replacing(clock: clock, reducesMotion: reducesMotion)
        _ = renderer.core.render(baseline: 0)
        return renderer
    }

    /// A host in place of the one before it, which leaves; its window closes.
    private static func replacing(clock: TestClock?, reducesMotion: Bool) -> WinUIRenderer {
        shared?.tree.root?.leave()
        shared?.window?.close()
        WinUITestHost.window.show(nil)

        let renderer = WinUIRenderer(clock: clock.map { clock in { clock.now } }, reducesMotion: { reducesMotion })
        shared = renderer
        return renderer
    }

    /// Applies `patch` as one whole message, as a render does, and stands the root in the test's window.
    func apply(_ patch: HostPatch) {
        intake.take(patch, generation: intake.baseline &+ 1) { tree.apply($0, complete: true) }
        let root = (tree.root?.native as? WinUIElement)?.view
        guard WinUITestHost.window.content !== root else { return }
        WinUITestHost.window.show(root)
        WinUITestHost.pump()
    }

    /// The view of the element keyed `id`.
    func view(id: ElementId) -> WinUIView? {
        (tree.root?.first(id: id)?.native as? WinUIElement)?.view
    }

    /// One display frame at the clock's time, then the layout pass WinUI runs in it.
    func frame() {
        displayCycle.frame(now: frameClock.now())
        layOut()
    }

    /// Runs WinUI's layout pass over the shown tree now.
    func layOut() {
        let root = window?.content ?? WinUITestHost.window.content
        if let root { stateui_winui_update_layout(root.handle) }
    }

    /// Pumps until `done` holds: a handler resumed on the pool comes back to the UI thread's queue.
    func settle(until done: () -> Bool) {
        for _ in 0..<150 {
            if done() { return }
            WinUITestHost.pump(0.01)
            _ = core.runJobs()
            pump()
        }
    }

    /// Every view of `type` in the tree, in order.
    func views<Native: WinUIView>(_ type: Native.Type) -> [Native] {
        guard let root = tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: WinUIView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? WinUIElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }
}

extension WinUIView {
    /// Where WinUI laid the element out, rounded to whole DIPs.
    var frame: (x: Double, y: Double, width: Double, height: Double) {
        let frame = laidOutFrame
        return (frame.x.rounded(), frame.y.rounded(), frame.width.rounded(), frame.height.rounded())
    }

    /// The colours WinUI draws the element in at `points`, in DIPs of it, as ARGB - premultiplied, so a colour
    /// drawn half opaque reads half as bright.
    func pixels(at points: [(Double, Double)]) -> [UInt32] {
        let flat = points.flatMap { [$0.0, $0.1] }
        var argb = [UInt32](repeating: 0, count: points.count)
        XCTAssertTrue(stateui_winui_pixels(handle, flat, Int32(points.count), &argb), "WinUI rendered nothing")
        return argb
    }

    /// The opacity WinUI draws the element at.
    var drawnOpacity: Double {
        stateui_winui_opacity(handle)
    }

    /// The transform WinUI holds: translation, rotation, scale and the centre it turns about, in DIPs and degrees.
    var drawnTransform: (translationX: Double, translationY: Double, rotation: Double,
                         scaleX: Double, scaleY: Double, centerX: Double, centerY: Double) {
        var values = [Double](repeating: 0, count: 7)
        stateui_winui_transform(handle, &values)
        return (values[0], values[1], values[2], values[3], values[4], values[5], values[6])
    }
}

extension WinUIView {
    /// The view's context menu, or a bar's menus, as the relay reads them: items by caption, "!" before one that
    /// cannot be chosen, "-" a separator, a submenu's entries - and a bar's menu's - in brackets; empty for none.
    var menus: String {
        let length = Int(stateui_winui_menus(handle, nil, 0))
        var bytes = [CChar](repeating: 0, count: length + 1)
        _ = stateui_winui_menus(handle, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// What assistive technology meets of the view, as its automation peer says it: its name, help text and
    /// automation id.
    var automationWords: (name: String, help: String, identifier: String) {
        func read(_ what: Int32) -> String {
            let length = Int(stateui_winui_automation_words(handle, what, nil, 0))
            var bytes = [CChar](repeating: 0, count: length + 1)
            _ = stateui_winui_automation_words(handle, what, &bytes, Int32(bytes.count))
            return String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        return (read(0), read(1), read(2))
    }

    /// And its heading level, whether it is a control element and a content element, and how many children it has.
    var automationFacts: (heading: Int32, isControl: Bool, isContent: Bool, children: Int32) {
        var facts = [Int32](repeating: 0, count: 4)
        stateui_winui_automation_facts(handle, &facts)
        return (facts[0], facts[1] != 0, facts[2] != 0, facts[3])
    }

    /// Presses the view as assistive technology does, through its automation peer; whether it could be pressed.
    func press() -> Bool {
        stateui_winui_press(handle)
    }

    /// Whether a click at (`x`, `y`), in DIPs of the view, would reach the view itself.
    func hits(_ x: Double, _ y: Double) -> Bool {
        stateui_winui_hits(handle, x, y)
    }
}

extension WinUIButtonView {
    /// Presses the button as UI Automation does, then lets WinUI lay out what that changed.
    func invoke() {
        stateui_winui_button_invoke(handle)
        WinUITestHost.pump(0.05)
    }
}

extension WinUIToggleView {
    /// Turns the control as UI Automation does: a switch or a check box toggled, a radio button chosen.
    func toggle() {
        stateui_winui_toggle_press(handle)
    }
}

extension WinUIValueView {
    /// Moves the value to `value` as UI Automation does: a slider's thumb, a stepper's number.
    func move(to value: Double) {
        stateui_winui_value_move(handle, value)
    }
}

extension WinUIInputView {
    /// Changes the words as the user does: written outside a program's write, WinUI reports them the same - a
    /// search box's through the text box its template holds, where its own words would be the program's.
    /// Design: docs/design/platforms/winui/controls.md#a-field-and-its-words
    func type(_ text: String) {
        if self is WinUISearchFieldView {
            stateui_winui_search_type(handle, text)
        } else {
            stateui_winui_field_set_text(handle, text)
        }
    }
}
