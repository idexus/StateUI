// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import StateUIConformance
import XCTest

/// The test thread as WinUI's: WinUI embedded in it once, since no loop of WinUI's runs a test.
enum WinUITestHost {
    /// Makes the test thread hold WinUI elements, once, the tests' own pictures the application's.
    static func embed() {
        var callbacks = WinUICallbacks.table
        precondition(stateui_winui_embed(&callbacks) == 0, "WinUI could not stand on the test thread")
        stateui_winui_set_pictures(pictures)
    }

    /// The package's Tests/Resources/Images.
    static let pictures: String = {
        var path = #filePath
        for _ in 0..<4 { path = String(path[..<(path.lastIndex { $0 == "\\" || $0 == "/" } ?? path.endIndex)]) }
        return path + "/Tests/Resources/Images"
    }()

    /// Runs the thread's messages for `seconds`: a window's first frame, and the layout WinUI asks for.
    static func pump(_ seconds: Double = 0.2) {
        stateui_winui_pump(seconds)
    }

    /// The room a test's window stands in whatever the screen - Windows gives a window three quarters of it -
    /// as AppKit's and GTK's windows open.
    static let room = LayoutSize(width: 560, height: 440)

    /// A room where a split view's sidebar stands beside its detail, which a screen of 1024 x 768 holds.
    @MainActor static let wideRoom = LayoutSize(width: WinUISidebarView.expandsAt + 8, height: 700)

    /// The window a bare host's root stands in, made once.
    @MainActor static let window: WinUIWindow = {
        let window = WinUIWindow()
        window.request(WindowFrame(width: room.width, height: room.height))
        return window
    }()
}

extension XCTestCase {
    /// Runs `body` as the main actor's on the test thread, which holds WinUI and is claimed as the UI thread first.
    func onUIThread<Result: Sendable>(_ body: @MainActor () throws -> Result) rethrows -> Result {
        WinUITestHost.embed()
        CoreLink().claimUIThread()
        return try MainActor.assumeIsolated(body)
    }
}

extension WinUIRenderer {
    /// A host showing `page` in a window of its own, laid out in `room`, on `clock` where one is given.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, room: LayoutSize = WinUITestHost.room,
        @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> WinUIRenderer {
        let application = OneWindowApplication(page: page)
        return running(
            clock: clock, reducesMotion: reducesMotion, room: room,
            application: { application })
    }

    /// A host running `application`, its windows laid out in `room` from the first layout - but for a size a window
    /// asks for itself, as a window opens at its host's size and then stands as it is asked - on `clock` where one
    /// is given.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, room: LayoutSize = WinUITestHost.room,
        application: @escaping @MainActor () -> any Application
    ) -> WinUIRenderer {
        Renderer.shared.setApplication(application())
        let renderer = replacing(clock: clock, reducesMotion: reducesMotion)
        renderer.start()
        for controller in renderer.windows {
            let asked = controller.element.map { WindowFrame(of: $0) } ?? WindowFrame()
            controller.window.request(WindowFrame(
                width: asked.width == nil ? room.width : nil, height: asked.height == nil ? room.height : nil))
        }
        renderer.waitForFirstLayout()
        return renderer
    }

    /// Runs the thread's messages until the window's content is laid out - its first frame - at most half a second:
    /// a start waits for its window, not a fixed time.
    func waitForFirstLayout() {
        for _ in 0..<25 {
            WinUITestHost.pump(0.02)
            if let content = window?.content, content.laidOutFrame.width > 0 { return }
        }
    }

    /// A host whose tree takes only what a test applies; its root stands in the test's window. The core's own
    /// render is taken and set aside, so no frame renders the core's tree over the test's.
    static func bare(clock: TestClock? = nil, reducesMotion: Bool = false) -> WinUIRenderer {
        let renderer = replacing(clock: clock, reducesMotion: reducesMotion)
        _ = renderer.runtime.core.render(baseline: 0)
        return renderer
    }

    /// A host in place of the one before it, which leaves; its window closes.
    private static func replacing(clock: TestClock?, reducesMotion: Bool) -> WinUIRenderer {
        shared?.runtime.tree.root?.leave()
        for controller in (shared?.windows ?? []).reversed() { controller.window.close() }
        WinUITestHost.window.show(nil)

        let renderer = WinUIRenderer(clock: clock.map { clock in { clock.now } }, reducesMotion: { reducesMotion })
        shared = renderer
        return renderer
    }

    /// Applies `patch` as one whole message, as a render does, and stands the root in the test's window.
    func apply(_ patch: HostPatch) {
        runtime.intake.take(patch, generation: runtime.intake.baseline &+ 1) { runtime.tree.apply($0, complete: true) }
        let root = (runtime.tree.root?.native as? WinUIElement)?.view
        guard WinUITestHost.window.content !== root else { return }
        WinUITestHost.window.show(root)
        WinUITestHost.pump()
    }

    /// The view of the element keyed `id`.
    func view(id: ElementID) -> WinUIView? {
        (runtime.tree.root?.first(id: id)?.native as? WinUIElement)?.view
    }

    /// One display frame at the clock's time, then the layout pass WinUI runs in it.
    func frame() {
        runtime.displayCycle.frame(now: frameClock.now())
        layOut()
    }

    /// Runs WinUI's layout pass over the shown tree now.
    func layOut() {
        let root = window?.content ?? WinUITestHost.window.content
        if let root { stateui_winui_update_layout(root.handle) }
    }

    /// Turns until `done` holds: a handler resumed on the pool comes back to the UI thread's queue.
    func settle(until done: () -> Bool) {
        for _ in 0..<150 {
            if done() { return }
            step()
        }
    }

    /// One bounded step: the thread's messages a moment - WinUI's frames among them - the jobs, a turn, and the
    /// frame a held clock waits for.
    func step() {
        WinUITestHost.pump(0.01)
        _ = runtime.core.runJobs()
        runtime.pump.turn()
        if frameClock.held { frame() }
    }

    /// Every view of `type` in the tree, in order.
    func views<Native: WinUIView>(_ type: Native.Type) -> [Native] {
        guard let root = runtime.tree.root else { return [] }
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

    /// The tip WinUI draws the element with, its projection's matrix; nil for none.
    var drawnTip: HostMatrix? {
        var numbers = [Double](repeating: 0, count: 16)
        guard stateui_winui_projection(handle, &numbers) else { return nil }
        var tip = HostMatrix.identity
        (tip.m11, tip.m12, tip.m13, tip.m14) = (numbers[0], numbers[1], numbers[2], numbers[3])
        (tip.m21, tip.m22, tip.m23, tip.m24) = (numbers[4], numbers[5], numbers[6], numbers[7])
        (tip.m31, tip.m32, tip.m33, tip.m34) = (numbers[8], numbers[9], numbers[10], numbers[11])
        (tip.m41, tip.m42, tip.m43, tip.m44) = (numbers[12], numbers[13], numbers[14], numbers[15])
        return tip
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

    /// And its heading level, whether it is a control element and a content element, and how many within it are met.
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

    /// Whether a click at (`x`, `y`), in DIPs of the view, would reach it or what stands in it through everything
    /// its window shows over it.
    func reaches(_ x: Double, _ y: Double) -> Bool {
        stateui_winui_reaches(handle, x, y)
    }

    /// Where `child`'s view is drawn among this view's children: its depth, then its place - the higher drawn
    /// later; nil where it stands in none of them.
    func drawnPlace(of child: WinUIView) -> (depth: Int32, place: Int32)? {
        var (depth, place): (Int32, Int32) = (0, 0)
        return stateui_winui_drawn_place(handle, child.handle, &depth, &place) ? (depth, place) : nil
    }
}

extension WinUIButtonView {
    /// Presses the button as UI Automation does, then lets WinUI lay out what that changed.
    func invoke() {
        stateui_winui_button_invoke(handle)
        WinUITestHost.pump(0.05)
    }
}

extension WinUIPickerView {
    /// The choices the picker holds, as WinUI has them.
    var choices: [String] {
        let length = Int(stateui_winui_picker_choices(handle, nil, 0))
        var bytes = [CChar](repeating: 0, count: length + 1)
        _ = stateui_winui_picker_choices(handle, &bytes, Int32(bytes.count))
        let joined = String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return joined.isEmpty ? [] : joined.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
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

extension WinUITextInputView {
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
