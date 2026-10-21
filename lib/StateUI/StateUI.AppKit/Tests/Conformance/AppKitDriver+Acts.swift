// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// What a user does, through the path AppKit's own input takes into the host: a control's action, an accessibility
/// action, the field editor, a recognizer's report, a menu's item, the window's notifications.
/// Design: docs/design/platforms/appkit/conformance.md#what-the-driver-does
extension AppKitDriver {
    /// Does `act`, what AppKit autoreleases on the way let go as it ends.
    func perform(_ act: UserAct, on element: MountedElement) throws {
        try autoreleasepool { try performing(act, on: element) }
    }

    private func performing(_ act: UserAct, on element: MountedElement) throws {
        layOutWindows()
        if element.type == .marker { return try performOnMarker(act, element) }
        let native = element.native as? AppKitElement
        let view = native?.view
        switch (act, view) {
        case (.tap(let count), let map as AppKitMapView):
            // A click on a map is the map's, and the view's where it hears taps too.
            for run in 1...max(count, 1) { native?.tapRecognizer?.clicked(run: run) }
            map.clicked(at: NSPoint(x: map.bounds.midX, y: map.bounds.midY))
        case (.endContent, let web as WebKitView):
            // As WebKit tells it when the page's process dies.
            web.navigationDelegate?.webViewWebContentProcessDidTerminate?(web)
        case (.activate, _) where element.parent?.type == .itemsView:
            guard let items = (element.parent?.native as? AppKitElement)?.view as? AppKitItemsView,
                  case .manual(let identity) = element.id
            else { throw DriverCannot(act, on: element) }
            items.activateForTesting(identity)
        case (.choose(let place), let items as AppKitItemsView): items.chooseForTesting(place)
        case (.scroll(let target), let items as AppKitItemsView): items.scrollForTesting(to: target)
        case (.activate, _): try activate(element, view)
        case (.pressKeys(let shortcut), _): try pressKeys(shortcut, on: element, view)
        case (.toggle, let toggle as AppKitSwitchView): _ = toggle.control.accessibilityPerformPress()
        case (.toggle, let check as AppKitCheckBoxView): check.performClick(nil)
        case (.toggle, let split as AppKitSplitView): split.toggleForTesting()
        case (.slide(let value), let slider as AppKitSliderView):
            slider.doubleValue = value
            slider.sendAction(slider.action, to: slider.target)
        case (.enterWords, is AppKitStepperView):
            throw DriverCannot("type words into a Stepper", because: "the Mac's stepper is two arrows, with no field")
        case (.step(let up), let stepper as AppKitStepperView):
            // What a click on either arrow does: the value one increment on, within the range, then the action.
            let stepped = stepper.doubleValue + (up ? stepper.increment : -stepper.increment)
            stepper.doubleValue = min(max(stepped, stepper.minValue), stepper.maxValue)
            stepper.sendAction(stepper.action, to: stepper.target)
        case (.type(let words), let field as AppKitTextFieldView): try type(words, into: field.textField)
        case (.type(let words), let search as AppKitSearchFieldView): try type(words, into: search)
        case (.type(let words), let editor as AppKitTextEditorView): try type(words, into: editor.textView)
        case (.submit, let field as AppKitTextFieldView): try submit(field.textField)
        case (.submit, let search as AppKitSearchFieldView): try submit(search)
        case (.choose(let place), let picker as any AppKitChoosing): picker.chooseForTesting(index: place)
        case (.choose(let place), let tabs as AppKitTabView): try choose(place, of: tabs, element)
        case (.open, let picker as AppKitPickerView): picker.menuWillOpen(NSMenu())
        case (.close, let picker as AppKitPickerView): picker.menuDidClose(NSMenu())
        case (.pickDate(let day), let picker as AppKitDatePickerView): picker.chooseForTesting(day)
        case (.pickTime(let time), let picker as AppKitTimePickerView): picker.chooseForTesting(time)
        case (.pressDown(let point), _) where native?.handReader != nil: native?.handReader?.dragging.pressed(at: point)
        case (.drag(let point), _) where native?.handReader != nil: native?.handReader?.dragging.moved(to: point)
        case (.lift, _) where native?.handReader != nil: native?.handReader?.dragging.released()
        case (.pressDown(let point), let view?): try press(view, native, down: true, at: point, element)
        case (.lift(let point), let view?): try press(view, native, down: false, at: point, element)
        case (.drag(let point), let canvas as AppKitCanvasView): canvas.dragForTesting(at: NSPoint(point))
        case (.drag(let point), _) where native?.pointerRecognizer != nil:
            native?.pointerRecognizer?.pointed(.pointerMoved, at: point)
        case (.hover(let point), _) where native?.pointerRecognizer != nil:
            native?.pointerRecognizer?.pointed(.pointerEntered, at: point)
            native?.pointerRecognizer?.pointed(.pointerMoved, at: point)
        case (.leave, _) where native?.pointerRecognizer != nil:
            native?.pointerRecognizer?.pointed(.pointerExited, at: Point(x: 0, y: 0))
        case (.tap(let count), _) where native?.tapRecognizer != nil:
            // A quick run of clicks, each told with its place in the run, as AppKit's click recognizer tells them.
            for run in 1...max(count, 1) { native?.tapRecognizer?.clicked(run: run) }
        case (.pan(let offset), _) where native?.panRecognizer != nil:
            native?.panRecognizer?.dragged(.began, x: 0, y: 0)
            native?.panRecognizer?.dragged(.changed, x: offset.x, y: offset.y)
            native?.panRecognizer?.dragged(.ended, x: offset.x, y: offset.y)
        case (.sweep(let offset, let speed), _) where native?.handReader != nil:
            native?.handReader?.hand(.began, moved: .zero)
            native?.handReader?.hand(.changed, moved: offset)
            native?.handReader?.hand(.ended, moved: .zero, speed: speed)
        case (.notch(let notches), _) where native?.handReader != nil:
            native?.handReader?.notched(notches)
        case (.pinch(let scale, let point), _) where native?.pinchRecognizer != nil:
            native?.pinchRecognizer?.pinched(.began, scale: 1, at: point)
            native?.pinchRecognizer?.pinched(.changed, scale: scale, at: point)
            native?.pinchRecognizer?.pinched(.ended, scale: scale, at: point)
        case (.rotate(let degrees, _), _) where native?.rotationRecognizer != nil:
            native?.rotationRecognizer?.rotated(.began, degrees: 0)
            native?.rotationRecognizer?.rotated(.changed, degrees: degrees)
            native?.rotationRecognizer?.rotated(.ended, degrees: degrees)
        case (.scroll(let offset), let scroll as AppKitScrollView):
            // A live scroll: its start, the user's move, and its rest.
            scroll.beginMovementForTesting()
            scroll.moveAsUserForTesting(to: NSPoint(offset))
            scroll.restForTesting()
        case (.focus, let view?):
            guard let window = view.window, let focusable = AppKitFocus.focusable(in: view) else {
                throw DriverCannot(act, on: element)
            }
            window.makeFirstResponder(focusable)
        case (.answer(let button, let words), _):
            guard renderer?.actToolkit.showing?.pressForTesting(button, typing: words) == true else {
                throw DriverCannot("press \(button): no question shows it")
            }
        case (.dragAndDrop(let target, let across), _):
            try dragAndDrop(element, onto: target, across: across)
        case (.dropFiles(let names), let view?):
            try dropFiles(names, on: view, element)
        case (.answerFiles(let names), _):
            guard let dialog = renderer?.fileToolkit.showing else { throw DriverCannot("answer a file dialog: none shows") }
            dialog.chooseForTesting(names.map { Self.files.appendingPathComponent($0) })
        case (.goBack, _) where element.type == .navigationStack: try controller(of: element).toolbarForTesting
            .performForTesting(AppKitWindowToolbar.back)
        case (.goBack, _) where element.type == .window:
            // A sheet's own way back is the user's taking it away; else the toolbar's way back.
            let controller = try controller(of: element)
            if controller.modalCountForTesting > 0 {
                controller.dismissTopModalForTesting()
            } else {
                controller.toolbarForTesting.performForTesting(AppKitWindowToolbar.back)
            }
        case (.switchAway, _) where element.type == .window:
            // Another application in front takes the keyboard and the main window from every window, all AppKit tells.
            for window in windows { leaveTheFront(window) }
        case (.switchBack, _) where element.type == .window:
            comeToTheFront(try window(of: element))
        case (.bringToFront, _) where element.type == .window:
            let front = try window(of: element)
            for window in windows where window !== front { leaveTheFront(window) }
            comeToTheFront(front)
        case (.minimize, _) where element.type == .window:
            let window = try window(of: element)
            leaveTheFront(window)
            tell(NSWindow.didMiniaturizeNotification, window)
        case (.restore, _) where element.type == .window:
            let window = try window(of: element)
            tell(NSWindow.didDeminiaturizeNotification, window)
            comeToTheFront(window)
        case (.close, _) where element.type == .window: try window(of: element).close()
        case (.performAccessibilityAction(let name), let view?):
            // The action VoiceOver offers on what it meets of the view, run as VoiceOver runs it.
            let target = native?.accessibilityTarget(of: view)
            _ = target?.accessibilityCustomActions()?.first { $0.name == name }?.handler?()
        case (.adjust(let step), let view?):
            guard let target = native?.accessibilityTarget(of: view) else { throw DriverCannot(act, on: element) }
            _ = step == .increment ? target.accessibilityPerformIncrement() : target.accessibilityPerformDecrement()
        default: throw DriverCannot(act, on: element)
        }
    }

    /// A click on a button, a menu's item chosen, a page's action taken from the toolbar, and
    /// a view that hears taps pressed as assistive technology presses it.
    private func activate(_ element: MountedElement, _ view: NSView?) throws {
        switch view {
        case let button as AppKitButtonView: button.performClick(nil)
        case let pressed as AppKitHitTestView where pressed.pressAction != nil: _ = pressed.accessibilityPerformPress()
        default:
            if element.type == .menuItem, let item = (element.native as? AppKitElement)?.platformMenuItem,
               let menu = item.menu {
                menu.performActionForItem(at: menu.index(of: item))
                return
            }
            if element.type == .toolbarItem {
                let identifier = NSToolbarItem.Identifier("StateUI.action.\(element.mount)")
                try controller(of: element).toolbarForTesting.performForTesting(identifier)
                return
            }
            throw DriverCannot(.activate, on: element)
        }
    }

    /// A pointer pressed down or let go: a button held, a slider's thumb taken, a canvas pressed, and a view that
    /// hears the pointer told.
    private func press(
        _ view: NSView, _ native: AppKitElement?, down: Bool, at point: Point, _ element: MountedElement
    ) throws {
        var done = false
        if let pointer = native?.pointerRecognizer {
            pointer.pointed(down ? .pointerPressed : .pointerReleased, at: point)
            done = true
        }
        switch view {
        case let button as AppKitButtonView:
            down ? button.onPressed?() : button.onReleased?()
            done = true
        case let slider as AppKitSliderView:
            down ? slider.beginDrag() : slider.endDrag()
            done = true
        case let canvas as AppKitCanvasView:
            down ? canvas.pressForTesting(at: NSPoint(point)) : canvas.releaseForTesting(at: NSPoint(point))
            done = true
        default: break
        }
        if !done { throw DriverCannot(down ? .pressDown(at: point) : .lift(at: point), on: element) }
    }

    /// Chooses the tab at `place`: in the row beneath the window's toolbar where the window shows the tabs, else in
    /// the tab view's own.
    private func choose(_ place: Int, of tabs: AppKitTabView, _ element: MountedElement) throws {
        if tabs.tabsShownByWindow {
            try controller(of: element).tabRowForTesting.chooseForTesting(place)
        } else {
            tabs.selectForTesting(place)
        }
    }

    /// The controller of the window `element` stands in.
    func controller(of element: MountedElement) throws -> AppKitWindowController {
        guard let window = element.type == .window ? element : element.enclosing(type: .window),
              let controller = renderer?.windowsForTesting.first(where: { $0.element === window })
        else { throw DriverCannot("find the window") }
        return controller
    }

    /// The native windows the host shows, in the tree's order.
    var windows: [NSWindow] {
        renderer?.windowsForTesting.compactMap(\.window) ?? []
    }

    /// The native window `element` stands in.
    func window(of element: MountedElement) throws -> NSWindow {
        guard let window = renderer?.windowsForTesting.first(where: { $0.element === element })?.window else {
            throw DriverCannot("find the window")
        }
        return window
    }

    /// Tells `window`'s delegate what AppKit tells it, as `name` is posted by the window itself.
    func tell(_ name: Notification.Name, _ window: NSWindow) {
        NotificationCenter.default.post(name: name, object: window)
    }

    /// `window` comes to the front, the main window holding the keyboard, as AppKit tells a window it brings
    /// forward. The driver shows no window on the machine's screen, so no run takes the user's.
    /// Design: docs/design/platforms/appkit/conformance.md#windows
    func comeToTheFront(_ window: NSWindow?) {
        guard let window else { return }
        tell(NSWindow.didBecomeMainNotification, window)
        tell(NSWindow.didBecomeKeyNotification, window)
    }

    /// `window` leaves the front: it is neither the main window nor holds the keyboard.
    func leaveTheFront(_ window: NSWindow) {
        tell(NSWindow.didResignKeyNotification, window)
        tell(NSWindow.didResignMainNotification, window)
    }

    /// Types `words` as the whole of a field's words, through the editor AppKit gives the field that holds the
    /// keyboard: what a user's typing reports, the field reports. A field that refuses the keyboard - read-only, it
    /// takes no editor - leaves the keys to the responder the window holds, as a user's keys go.
    private func type(_ words: String, into field: NSTextField) throws {
        guard let window = field.window else { throw DriverCannot("type into a field with no window") }
        guard window.makeFirstResponder(field), let editor = field.currentEditor() as? NSTextView else {
            (window.firstResponder as? NSTextInputClient)?
                .insertText(words, replacementRange: NSRange(location: NSNotFound, length: 0))
            return
        }
        editor.selectAll(nil)
        editor.insertText(words, replacementRange: editor.selectedRange())
    }

    /// Types `words` as the whole of an editor's words, as the keyboard does.
    private func type(_ words: String, into editor: NSTextView) throws {
        guard let window = editor.window, window.makeFirstResponder(editor) else {
            throw DriverCannot("type into an editor in no window")
        }
        editor.selectAll(nil)
        editor.insertText(words, replacementRange: editor.selectedRange())
    }

    /// Presses Return in `field`, which ends its editing as the keyboard's Return does.
    private func submit(_ field: NSTextField) throws {
        guard let window = field.window, window.makeFirstResponder(field),
              let editor = field.currentEditor() as? NSTextView
        else { throw DriverCannot("submit a field with no editor") }
        editor.insertNewline(nil)
    }
    /// `element` dragged onto the view of id `target` - across the one of id `across` first - as AppKit's dragging
    /// session tells it: its source starts, the window's root hears the drag over each view's middle and let go
    /// there, and the source ends.
    func dragAndDrop(_ element: MountedElement, onto target: String, across: String?) throws {
        let act = UserAct.dragAndDrop(onto: target, across: across)
        let native = element.native as? AppKitElement
        guard let source = native?.dragSource, let root = native?.view?.window?.contentView,
              let drops = (root as? AppKitWindowContentView)?.drops
        else { throw DriverCannot(act, on: element) }
        func middle(_ id: String) throws -> NSPoint {
            guard let view = (renderer?.runtime.tree.root?.first(id: .manual(id))?.native as? AppKitElement)?.view else {
                throw DriverCannot(act, on: element)
            }
            return view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
        }
        let carried = AppKitDrops.Carried(words: source.words)
        source.started()
        _ = drops.entered(at: try middle(across ?? target), carrying: carried, in: root)
        if across != nil { _ = drops.moved(to: try middle(target), carrying: carried, in: root) }
        _ = drops.dropped(carried)
        source.ended()
    }

    /// Files of `names`, written in the driver's folder, dragged from the system onto `view` and let go there, as
    /// AppKit's dragging destination tells the window's root.
    func dropFiles(_ names: [String], on view: NSView, _ element: MountedElement) throws {
        guard let root = view.window?.contentView,
              let drops = (root as? AppKitWindowContentView)?.drops
        else { throw DriverCannot(.dropFiles(names), on: element) }
        let files = names.map { Self.files.appendingPathComponent($0) }
        for file in files { try Data(file.lastPathComponent.utf8).write(to: file) }
        let carried = AppKitDrops.Carried(files: files)
        _ = drops.entered(at: view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil), carrying: carried, in: root)
        _ = drops.dropped(carried)
    }

    /// A shortcut pressed while the element's window is in front: the key-down AppKit makes of it, offered to the
    /// window's key equivalents, then the main menu's, then to the view holding the keyboard, as AppKit offers it.
    private func pressKeys(_ shortcut: KeyboardShortcut, on element: MountedElement, _ view: NSView?) throws {
        // What a keyboard sends, not what a key equivalent is spelled with: Delete is DEL there.
        let spelled = (key: AppKitKeys.typed(of: shortcut), modifiers: AppKitKeys.equivalent(of: shortcut).modifiers)
        let controller = try? controller(of: element)
        guard let window = view?.window ?? controller?.window ?? NSApp.windows.first(where: \.isVisible),
              let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: spelled.modifiers, timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: spelled.key,
                charactersIgnoringModifiers: spelled.key, isARepeat: false, keyCode: 0)
        else { throw DriverCannot(.pressKeys(shortcut), on: element) }
        // The window in front: its page's menus on the menu bar, as AppKit puts them there for the key window - and
        // off it again, so no later window finds them.
        if NSApp.mainMenu == nil { NSApp.mainMenu = StateUIAppKit.mainMenu(newWindow: nil) }
        controller?.host?.installPageMenus(controller?.pageMenus ?? [])
        defer { controller?.host?.installPageMenus([]) }
        // The application's key monitor first, as AppKit hands it every key: one a view takes ends there.
        guard let offered = AppKitWindow.offered(event) else { return }
        if window.performKeyEquivalent(with: offered) || NSApp.mainMenu?.performKeyEquivalent(with: offered) == true {
            return
        }
        window.sendEvent(offered)
    }
}

extension NSPoint {
    /// A point of StateUI's, in AppKit's units.
    init(_ point: Point) {
        self.init(x: point.x, y: point.y)
    }
}
#endif
