// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@_spi(Host) import StateUIConformance

/// The WinUI host as the conformance suite drives it: each user's act through UI Automation's pattern or the path
/// WinUI's own input takes into the host, and each read from the control itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class WinUIDriver: HostDriver {
    let host = "WinUI 3"
    let cannot = [
        "submit on TextField":
            "WinUI raises a text box's KeyDown only from the keyboard; Enter is walked on HelloWorld's field",
        "read growsWithText of TextEditor":
            "an editor's growing is StateUI's measuring, which no property of WinUI's holds; its frames prove it",
        "read aspect of Rectangle": "WinUI places a shape's figure itself, and holds no aspect; its drawing proves it",
        "read aspect of Ellipse": "WinUI places a shape's figure itself, and holds no aspect; its drawing proves it",
        "read aspect of Line": "WinUI places a shape's figure itself, and holds no aspect; its drawing proves it",
        "read aspect of Path": "WinUI places a shape's figure itself, and holds no aspect; its drawing proves it",
        "read aspect of Polygon": "WinUI places a shape's figure itself, and holds no aspect; its drawing proves it",
        "read aspect of Polyline": "WinUI places a shape's figure itself, and holds no aspect; its drawing proves it",
        "read renderTransform of Rectangle": "WinUI folds a shape's transform into its figure; its drawing proves it",
        "read renderTransform of Ellipse": "WinUI folds a shape's transform into its figure; its drawing proves it",
        "read renderTransform of Line": "WinUI folds a shape's transform into its figure; its drawing proves it",
        "read renderTransform of Path": "WinUI folds a shape's transform into its figure; its drawing proves it",
        "read renderTransform of Polygon": "WinUI folds a shape's transform into its figure; its drawing proves it",
        "read renderTransform of Polyline": "WinUI folds a shape's transform into its figure; its drawing proves it",
        "read format of TimePicker":
            "WinUI's time picker holds no format: it writes hours and minutes in the user's own clock",
        "read maximumLength of TextField": "WinUI's text box holds no bound: the host cuts what is typed; typing proves it",
        "read maximumLength of TextEditor": "WinUI's text box holds no bound: the host cuts what is typed; typing proves it",
        "read maximumLength of SearchField": "WinUI's search box holds no bound: the host cuts what is typed; typing proves it",
        "read padding of Grid": "WinUI's panel places its children where StateUI's layout says; their frames prove it",
        "read padding of HStack": "WinUI's panel places its children where StateUI's layout says; their frames prove it",
        "read padding of VStack": "WinUI's panel places its children where StateUI's layout says; their frames prove it",
        "read padding of ZStack": "WinUI's panel places its children where StateUI's layout says; their frames prove it",
        "read padding of ScrollView": "WinUI's panel places its children where StateUI's layout says; their frames prove it",
        "read spacing of HStack": "WinUI's panel places its children where StateUI's layout says; their frames prove it",
        "read spacing of VStack": "WinUI's panel places its children where StateUI's layout says; their frames prove it",
    ]

    /// The host the driver started last.
    var renderer: WinUIRenderer?

    /// What the host wrote to its log since the driver started it.
    let written = WinUILogLines()

    var register: HostRegister { WinUIRealization.register }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        written.listen()
        Self.emptyStore()
        let renderer = WinUIRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func forgetWhatIsKept() {
        Self.emptyStore()
    }

    func step() {
        renderer?.step()
    }

    func turn() {
        renderer?.runtime.pump.turn()
    }

    func frame() {
        renderer?.frame()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? WinUIElement)?.view
        switch (act, view) {
        case (.activate, _): try activate(element, view)
        case (.toggle, let toggle as WinUIToggleView): toggle.toggle()
        case (.toggle, _) where element.type == .splitView: try window().titleBar.chose(-2)
        case (.slide(let value), let slider as WinUISliderView): slider.move(to: value)
        case (.step(let up), let stepper as WinUIStepperView): stateui_winui_stepper_step_as_user(stepper.handle, up)
        case (.enterWords(let words), let stepper as WinUIStepperView):
            stateui_winui_stepper_enter_as_user(stepper.handle, words)
        case (.type(let words), let search as WinUISearchFieldView):
            // A search box tells the words a moment after it takes them, as a key is told before the next is typed.
            search.type(words)
            for _ in 0..<150 where element.value(.text)?.string != words { step() }
        case (.type(let words), let field as WinUIInputView): type(words, into: field)
        case (.submit, let search as WinUISearchFieldView): stateui_winui_search_submit_as_user(search.handle)
        case (.choose(let place), let picker as WinUIPickerView):
            stateui_winui_picker_choose_as_user(picker.handle, Int32(place))
        case (.choose(let place), _) where element.type == .tabbedView: try chooseTab(place, of: element)
        case (.open, let picker as WinUIPickerView): stateui_winui_picker_open_as_user(picker.handle, true)
        case (.close, let picker as WinUIPickerView): stateui_winui_picker_open_as_user(picker.handle, false)
        case (.open, let picker as WinUIDatePickerView): stateui_winui_date_set_open(picker.handle, true)
        case (.close, let picker as WinUIDatePickerView): stateui_winui_date_set_open(picker.handle, false)
        case (.pickDate(let day), let picker as WinUIDatePickerView):
            stateui_winui_date_pick_as_user(picker.handle, Int32(day.year), Int32(day.month), Int32(day.day))
        case (.pickTime(let time), let picker as WinUITimePickerView):
            stateui_winui_time_pick_as_user(picker.handle, Int32(time.hour), Int32(time.minute))
        case (.pressDown(let point), let view?): try press(view, down: true, at: point, element)
        case (.lift(let point), let view?): try press(view, down: false, at: point, element)
        case (.drag(let point), let canvas as WinUICanvasView): canvas.pressed(phase: 1, at: point)
        case (.drag(let point), let view?) where view.hearing.contains(.pointer):
            view.heard(.pointer(.pointerMoved, point))
        case (.hover(let point), let view?) where view.hearing.contains(.pointer):
            view.heard(.pointer(.pointerEntered, point))
            view.heard(.pointer(.pointerMoved, point))
        case (.leave, let view?) where view.hearing.contains(.pointer):
            view.heard(.pointer(.pointerExited, Point(x: 0, y: 0)))
        case (.tap(let count), let view?) where view.hearing.contains(.taps):
            for run in 1...max(count, 1) { view.heard(.tap(run: run)) }
        case (.pan(let offset), let view?) where view.hearing.contains(.drags):
            // The press the relay tells, which the host layer's rule makes a drag.
            view.heardPress(phase: 0, at: Point(x: 100, y: 100))
            view.heardPress(phase: 1, at: Point(x: 100 + offset.x, y: 100 + offset.y))
            view.heardPress(phase: 2, at: Point(x: 100 + offset.x, y: 100 + offset.y))
        case (.pinch(let scale, let point), let view?) where view.hearing.contains(.pinches):
            view.heard(.pinch(.started, scale: 1, at: point))
            view.heard(.pinch(.running, scale: scale, at: point))
            view.heard(.pinch(.completed, scale: 1, at: point))
        case (.scroll(let offset), let scroll as WinUIScrollView): scroll.scroller.move(to: offset)
        case (.focus, let view?): _ = stateui_winui_focus(view.handle, true)
        case (.goBack, _) where element.type == .navigationStack: try window().titleBar.chose(-1)
        case (.goBack, _) where element.type == .window: try window().titleBar.chose(-3)
        case (.close, _) where element.type == .window: stateui_winui_window_close(try window(of: element).handle)
        case (.minimize, _) where element.type == .window: try state(of: element, minimized: true, activated: false)
        case (.restore, _) where element.type == .window: try state(of: element, minimized: false, activated: true)
        case (.switchAway, _) where element.type == .window:
            for window in renderer?.windows ?? [] {
                WinUICallbacks.table.windowStateChanged(window.window.number, false, false)
            }
        case (.switchBack, _) where element.type == .window: try state(of: element, minimized: false, activated: true)
        case (.bringToFront, _) where element.type == .window:
            let front = try window(of: element)
            for window in renderer?.windows ?? [] where window.window !== front {
                WinUICallbacks.table.windowStateChanged(window.window.number, false, false)
            }
            try state(of: element, minimized: false, activated: true)
        case (.answer(let caption, let words), _): try answer(caption, typing: words)
        default: throw DriverCannot(act, on: element)
        }
    }

    /// The window the host shows its page in.
    func window() throws -> WinUIWindow {
        guard let window = renderer?.window else { throw DriverCannot("find the window") }
        return window
    }

    /// The window `element` stands in.
    func window(of element: MountedElement) throws -> WinUIWindow {
        guard let window = renderer?.controller(of: element)?.window else { throw DriverCannot("find the window") }
        return window
    }

    /// Tells the state of the window `element` stands in as its own events do.
    private func state(of element: MountedElement, minimized: Bool, activated: Bool) throws {
        WinUICallbacks.table.windowStateChanged(try window(of: element).number, minimized, activated)
    }

    /// A click on a button, a menu's item chosen, a toolbar's action chosen, a view that hears taps pressed as
    /// assistive technology presses it.
    private func activate(_ element: MountedElement, _ view: WinUIView?) throws {
        switch view {
        case let button as WinUIButtonView:
            stateui_winui_button_invoke(button.handle)
            return
        case let view? where view.hearing.contains(.taps):
            guard stateui_winui_press(view.handle) else { throw DriverCannot(.activate, on: element) }
            return
        default: break
        }
        if element.type == .menuItem, let (owner, index) = menuPlace(of: element) {
            stateui_winui_menus_choose(owner.handle, Int32(index))
            return
        }
        if element.type == .toolbarItem, let index = try actionPlace(of: element) {
            try window().titleBar.chose(index)
            return
        }
        throw DriverCannot(.activate, on: element)
    }

    /// A pointer pressed down or let go: a button held, a canvas pressed, a slider's thumb taken, and a view that hears
    /// the pointer told.
    private func press(_ view: WinUIView, down: Bool, at point: Point, _ element: MountedElement) throws {
        var done = false
        if view.hearing.contains(.pointer) {
            view.heard(.pointer(down ? .pointerPressed : .pointerReleased, point))
            done = true
        }
        switch view {
        case let button as WinUIButtonView:
            WinUICallbacks.table.held(button.number, down)
            done = true
        case let canvas as WinUICanvasView:
            canvas.pressed(phase: down ? 0 : 2, at: point)
            done = true
        case let slider as WinUISliderView:
            WinUICallbacks.table.held(slider.number, down)
            done = true
        default: break
        }
        if !done { throw DriverCannot(down ? .pressDown(at: point) : .lift(at: point), on: element) }
    }

    /// Chooses the tab at `place` of a tabbed view: in the window's row where the window shows its tabs, else in the row
    /// the view shows.
    private func chooseTab(_ place: Int, of element: MountedElement) throws {
        guard let tabs = (element.native as? WinUIElement)?.view as? WinUITabbedView else {
            throw DriverCannot(.choose(place), on: element)
        }
        let row: WinUIView = tabs.tabsShownByWindow ? try window().tabRow : tabs.row
        stateui_winui_tabs_choose_as_user(row.handle, Int32(place))
    }

    /// Answers the question showing as the user does, by its button of `caption`, its field first holding `words`:
    /// a dialog takes a press once WinUI has shown it whole, so the press is tried until it lands.
    private func answer(_ caption: String, typing words: String?) throws {
        guard let content = try window().content else { throw DriverCannot("answer a question with no window") }
        for _ in 0..<150 {
            if let asked = asked(over: content.handle), let button = Self.button(of: caption, in: asked),
               stateui_winui_answer(content.handle, button, words) {
                WinUITestHost.pump(0.05)
                return
            }
            step()
        }
        throw DriverCannot("answer by \(caption)")
    }

    /// The place of the dialog's button of `caption`: its accept 0, its cancel 1, its choices from 2; nil for none.
    private static func button(of caption: String, in asked: WinUIAsked) -> Int32? {
        if caption == asked.accept { return 0 }
        if caption == asked.cancel { return 1 }
        return asked.choices.firstIndex(of: caption).map { Int32($0 + 2) }
    }

    /// Types `words` as the whole of a field's words: written outside a program's write, which WinUI reports through
    /// the keyboard's `TextChanging`; a box WinUI holds read only takes none, as its keyboard takes none.
    /// Design: docs/design/platforms/winui/conformance.md#typing
    private func type(_ words: String, into field: WinUIInputView) {
        var facts = [Int32](repeating: 0, count: 9)
        stateui_winui_field_facts(field.handle, &facts)
        guard facts[0] == 0 else { return }
        stateui_winui_field_set_text(field.handle, words)
    }

    /// The folder the host keeps the application's values in while a test drives it, its own and empty at each start.
    private static let store: String = {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-conformance-\(ProcessInfo.processInfo.processIdentifier)").path
        stateui_winui_set_store(folder)
        return folder
    }()

    private static func emptyStore() {
        for file in [WinUIPersistence.valuesFile, WinUIPersistence.scenesFile] {
            try? FileManager.default.removeItem(atPath: store + "\\" + file)
        }
    }
}
