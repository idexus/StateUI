// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// The UIKit host as the conformance suite drives it: each user's act through the control event or the delegate
/// call UIKit's own input takes into the host, and each read from the control itself.
/// Design: docs/design/host/conformance.md#the-driver
@MainActor
final class UIKitDriver: HostDriver {
    let host = "UIKit"
    let cannot = [
        "read the line of a shape drawing no outline":
            "UIKit draws no outline for a shape given no stroke, and holds none of its line",
        "read verticalScrollIndicator of ScrollView":
            "UIKit shows a scroll indicator only while the user scrolls: always and as UIKit decides show alike",
        "read horizontalScrollIndicator of ScrollView":
            "UIKit shows a scroll indicator only while the user scrolls: always and as UIKit decides show alike",
    ]
    let platformHasNone = UIKitDriver.none()

    /// What UIKit holds none of: a shape's figure placed and moved by StateUI into its path, a layout's outline held
    /// as a path, where StateUI's layout places the children and what StateUI measures - each proven by its effect
    /// in another case.
    private static func none() -> [String: String] {
        var none = [
            "read growsWithText of TextEditor":
                "an editor's growing is StateUI's measuring, which no property of UIKit's holds; its frames prove it",
        ]
        for shape in ["Capsule", "Ellipse", "Line", "Path", "Polygon", "Polyline", "Rectangle"] {
            for member in ["contentMode", "geometryTransform"] {
                none["read \(member) of \(shape)"] =
                    "StateUI places and moves a shape's figure into its layer's path, which holds no \(member); its drawing proves it"
            }
        }
        for region in ["Fill", "Space"] {
            none["read shape of \(region)"] = "UIKit holds a box's outline as its layer's path, no shape; its drawing proves it"
        }
        for layout in ["Grid", "HStack", "VStack", "ZStack", "ScrollView"] {
            none["read shape of \(layout)"] =
                "UIKit holds a layout's outline as its layer's path, no shape; its drawing proves it"
            for member in ["padding", "ignoresSafeArea"] {
                none["read \(member) of \(layout)"] =
                    "UIKit's view places its children where StateUI's layout says; their frames prove it"
            }
        }
        for stack in ["HStack", "VStack"] {
            none["read spacing of \(stack)"] = "UIKit's view places its children where StateUI's layout says; their frames prove it"
        }
        return none
    }

    /// What the families ask of a driver that UIKit's has no path for yet says so, and stays empty in UIKit's column
    /// with why, rather than failing.
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "UIKit's driver has no path for it yet"
    }

    /// The host the driver started last.
    private(set) var renderer: UIKitRenderer?

    /// What the hosts wrote to their log since the last one started.
    private let written = UIKitLogLines()

    /// The press a finger holds down between the acts that put it down, drag it and lift it.
    var press: (pan: DrivenPan, dragging: Bool)?

    var register: HostRegister { UIKitRealization.register }

    func start(
        clock: TestClock?, reducesMotion: Bool, @ViewBuilder _ page: @escaping @MainActor () -> any View
    ) -> MountedTree {
        finish()
        forgetWhatIsKept()
        written.listen()
        let renderer = UIKitRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        Self.holdFiles(of: renderer)
        return renderer.runtime.tree
    }

    /// Runs `application` on a new host, as the next launch does: what the last kept stands.
    func start(clock: TestClock?, application: @escaping @MainActor () -> any Application) throws -> MountedTree {
        finish()
        written.listen()
        let renderer = UIKitRenderer.running(clock: clock, application: application)
        self.renderer = renderer
        Self.holdFiles(of: renderer)
        return renderer.runtime.tree
    }

    func forgetWhatIsKept() {
        TestScene.forgetWhatIsKept()
    }

    /// A menu item's action in the menu UIKit is handed now - the menu bar's, or the context menu of the view it
    /// stands under.
    func menuAction(of element: MountedElement) -> UIAction? {
        builtMenus(around: element)
        return (element.native as? UIKitElement)?.menuAction
    }

    /// The key commands among `elements` and in their submenus, in order.
    static func keyCommands(in elements: [UIMenuElement]) -> [UIKeyCommand] {
        elements.flatMap { element -> [UIKeyCommand] in
            if let command = element as? UIKeyCommand { return [command] }
            return (element as? UIMenu).map { keyCommands(in: $0.children) } ?? []
        }
    }

    /// A menu's entry stating a shortcut, as the menu UIKit is handed now holds it: a key command.
    func menuCommand(of element: MountedElement) -> UIKeyCommand? {
        builtMenus(around: element)
        return (element.native as? UIKitElement)?.menuCommand
    }

    /// Builds the menus `element` stands in, as UIKit asks for them: the menu bar's, or the context menu of the view
    /// it stands under.
    private func builtMenus(around element: MountedElement) {
        _ = renderer?.menuBar
        var holder = element.parent
        while let each = holder, (each.native as? UIKitElement)?.view == nil { holder = each.parent }
        _ = (holder?.native as? UIKitElement)?.builtContextMenu
    }

    /// What the hosts wrote to their log since the driver last started one.
    func logged() throws -> [String] {
        written.lines
    }

    var liveViews: Int? {
        UIKitElement.liveViewCount
    }

    /// Whether the element's view, or a view in it, holds the focus.
    func focused(_ element: MountedElement) throws -> Bool {
        guard let view = (element.native as? UIKitElement)?.view else {
            throw DriverCannot("read the focus of \(element.type.name)")
        }
        return UIKitElement.holdsFocus(view)
    }

    /// The view that takes the focus for `view`: it, or the first view in it that can.
    private static func focusable(in view: UIView) -> UIView? {
        if view.canBecomeFirstResponder { return view }
        for child in view.subviews { if let found = focusable(in: child) { return found } }
        return nil
    }

    /// Ends the host the driver started last.
    func finish() {
        renderer?.fileToolkit.showing?.chooseForTesting([])
        renderer?.finish()
        renderer = nil
    }

    /// `element` dragged onto the view of id `target` - across the one of id `across` first - as UIKit's
    /// interactions tell it: the drag starts, comes over the view crossed and goes, comes over the target and is let
    /// go there, and ends.
    func dragAndDrop(_ element: MountedElement, onto target: String, across: String?) throws {
        let act = UserAct.dragAndDrop(onto: target, across: across)
        func interactions(_ id: String) throws -> UIKitDragAndDrop {
            let found = renderer?.runtime.tree.root?.first(id: .manual(id))?.native as? UIKitElement
            guard let dragAndDrop = found?.dragAndDrop, dragAndDrop.offered.takesWords else {
                throw DriverCannot(act, on: element)
            }
            return dragAndDrop
        }
        guard let source = (element.native as? UIKitElement)?.dragAndDrop, let words = source.offered.words else {
            throw DriverCannot(act, on: element)
        }
        source.hearForTesting(.dragStarted)
        if let across {
            let crossed = try interactions(across)
            crossed.hearForTesting(.dragOver)
            crossed.hearForTesting(.dragLeft)
        }
        let landing = try interactions(target)
        landing.hearForTesting(.dragOver)
        landing.hearForTesting(.dropped(words))
        source.hearForTesting(.dragEnded)
    }

    /// The folder the files a test opens and saves stand in, the process's own.
    static let files = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-conformance-files")

    /// Empties the files folder, so no case reads a file another saved, and holds `renderer`'s launches back.
    private static func holdFiles(of renderer: UIKitRenderer) {
        try? FileManager.default.removeItem(at: files)
        try? FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        renderer.fileToolkit.holdsLaunchesForTesting = true
        renderer.actToolkit.announcedForTesting = []
        // A pasteboard of the driver's own name: a run never writes over the simulator's, which the Mac's follows.
        renderer.actToolkit.pasteboard = UIPasteboard(name: UIPasteboard.Name("org.stateui.conformance"), create: true)!
    }

    /// One pass of the main loop, 20 ms long: a case's 150 steps wait three seconds, which a page WebKit loads in a
    /// process of its own takes on a busy Mac. What UIKit autoreleases in it is let go as it ends.
    func step() {
        guard let renderer else { return }
        autoreleasepool {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
            _ = renderer.runtime.core.runJobs()
            renderer.runtime.pump.turn()
            renderer.layOut()
            if renderer.frameClock.held { renderer.frame() }
        }
    }

    func turn() {
        renderer?.runtime.pump.turn()
        renderer?.layOut()
    }

    func frame() {
        renderer?.frame()
    }

    /// Does `act`, what UIKit autoreleases on the way let go as it ends.
    func perform(_ act: UserAct, on element: MountedElement) throws {
        try autoreleasepool { try performing(act, on: element) }
    }

    private func performing(_ act: UserAct, on element: MountedElement) throws {
        if element.type == .marker { return try performOnMarker(act, element) }
        let view = (element.native as? UIKitElement)?.view
        switch (act, view) {
        case (.pressKeys(let shortcut), _):
            // The key command the element's window offers for the shortcut, performed as UIKit performs it - else a
            // menu bar's entry's, which UIKit sends up the responder chain to the root after text takes a key typed.
            guard let root = Self.windowRoot(of: element) else { return }
            if let command = root.keyCommands?.first(where: { UIKitKeys.shortcut(of: $0) == shortcut }),
               let action = command.action {
                _ = root.perform(action, with: command)
            } else if let command = Self.keyCommands(in: renderer?.menuBar ?? []).first(where: {
                          UIKitKeys.shortcut(of: $0) == shortcut
                      }),
                      !command.attributes.contains(.disabled),
                      !(KeyboardShortcuts.givesWayToTyping(shortcut) && UIKitFirstResponder.isTyping) {
                root.chooseMenuEntry(command)
            }
        case (.tap(let count), let map as UIKitMapView):
            // A tap on a map is the map's, and the view's where it hears taps too.
            try touch(element) { listening, view in Self.tap(listening, on: view, count: count) }
            map.clicked(at: CGPoint(x: map.bounds.midX, y: map.bounds.midY))
        case (.activate, _) where element.parent?.type == .itemsView:
            guard let items = (element.parent?.native as? UIKitElement)?.view as? UIKitItemsView,
                  case .manual(let identity) = element.id
            else { throw DriverCannot(act, on: element) }
            items.activateForTesting(identity)
        case (.choose(let place), let items as UIKitItemsView): items.chooseForTesting(place)
        case (.scroll(let target), let items as UIKitItemsView): items.scrollForTesting(to: target)
        // UIKit lets a touch reach no control that is not enabled.
        case (.activate, let button as UIKitButtonView): if button.isEnabled { button.sendActions(for: .primaryActionTriggered) }
        case (.activate, let link as UIKitLinkView): if link.isEnabled { link.sendActions(for: .primaryActionTriggered) }
        case (.type(let words), let editor as UIKitTextEditorView):
            // UIKit asks the editor's delegate before any change a key makes.
            let whole = NSRange(location: 0, length: editor.text.utf16.count)
            guard editor.isEditable,
                  editor.delegate?.textView?(editor, shouldChangeTextIn: whole, replacementText: words) ?? true
            else { return }
            editor.text = words
            editor.delegate?.textViewDidChange?(editor)
        case (.type(let words), let field as UITextField & UIKitTextInputView):
            let whole = NSRange(location: 0, length: field.words.utf16.count)
            guard field.delegate?.textField?(field, shouldChangeCharactersIn: whole, replacementString: words) ?? true
            else { return }
            field.text = words
            field.sendActions(for: .editingChanged)
        case (.submit, let field as UITextField & UIKitTextInputView): _ = field.delegate?.textFieldShouldReturn?(field)
        case (.toggle, let toggle as UIKitSwitchView):
            toggle.control.setOn(!toggle.isOn, animated: false)
            toggle.control.sendActions(for: .valueChanged)
        case (.toggle, let check as UIKitCheckView): check.sendActions(for: .primaryActionTriggered)
        case (.slide(let value), let slider as UIKitSliderView):
            slider.sendActions(for: .touchDown)
            slider.value = Float(value)
            slider.sendActions(for: .valueChanged)
            slider.sendActions(for: .touchUpInside)
        case (.step(let up), let stepper as UIKitStepperView):
            // A button that would step past an end is off, and says nothing.
            let stepped = min(max(stepper.value + (up ? stepper.stepValue : -stepper.stepValue), stepper.minimumValue),
                              stepper.maximumValue)
            guard stepped != stepper.value else { return }
            stepper.value = stepped
            stepper.sendActions(for: .valueChanged)
        case (.enterWords, is UIKitStepperView):
            throw DriverCannot("type words into a Stepper", because: "iOS's stepper is two buttons, with no field")
        case (.pullToRefresh, let pulled as any UIKitRefreshing):
            // A finger pulls past the top far enough: the control spins, and says it was pulled.
            guard let control = pulled.refresh.scroller?.refreshControl else { throw DriverCannot(act, on: element) }
            control.beginRefreshing()
            control.sendActions(for: .valueChanged)
        case (.scroll(let target), let scroll as UIKitScrollView):
            // A finger takes the scroller, moves it there, and lets go without a throw.
            scroll.scrollViewWillBeginDragging(scroll.scroller)
            scroll.scroller.contentOffset = scroll.native(of: target)
            scroll.scrollViewDidEndDragging(scroll.scroller, willDecelerate: false)
        case (.choose(let place), let picker as any UIKitChoosing): picker.userChose(place)
        case (.endContent, let web as WebKitView):
            // As WebKit tells it when the page's process dies.
            web.navigationDelegate?.webViewWebContentProcessDidTerminate?(web)
        case (.focus, let view?):
            // A finger in a field: it takes the keyboard.
            guard let focusable = Self.focusable(in: view) else { throw DriverCannot(act, on: element) }
            focusable.becomeFirstResponder()
            renderer?.focusMoved()
        case (.answer(let button, let words), _):
            guard renderer?.actToolkit.showing?.press(button, typing: words) == true else {
                throw DriverCannot("press \(button): no question shows it")
            }
        case (.dragAndDrop(let target, let across), _):
            try dragAndDrop(element, onto: target, across: across)
        case (.dropFiles(let names), _):
            guard let dragAndDrop = (element.native as? UIKitElement)?.dragAndDrop, dragAndDrop.offered.takesFiles else {
                throw DriverCannot(act, on: element)
            }
            let files = names.map { Self.files.appendingPathComponent($0) }
            for file in files { try Data(file.lastPathComponent.utf8).write(to: file) }
            dragAndDrop.hearForTesting(.filesDropped(files.map(ChosenFile.init)))
        case (.answerShare(let shared), _):
            guard let sheet = renderer?.actToolkit.sharing else { throw DriverCannot("answer a share sheet: none shows") }
            sheet.answerForTesting(shared: shared)
        case (.answerFiles(let names), _):
            guard let dialog = renderer?.fileToolkit.showing, dialog.picker != nil else {
                throw DriverCannot("answer a file dialog: none shows")
            }
            dialog.chooseForTesting(names.map { Self.files.appendingPathComponent($0) })
        case (.openLink(let address), _):
            // The scene's delegate hands its URL contexts to the host's entry, which no driver can make.
            let window = element.type == .window ? element : element.enclosing(type: .window)
            guard let scene = renderer?.roster.windows.first(where: { $0.0 === window })?.1.window?.windowScene else {
                throw DriverCannot(act, on: element)
            }
            renderer?.openLinks([address], in: scene)
        case (.switchAway, _) where element.type == .window: renderer?.window(element, movedTo: .inactive)
        case (.switchBack, _) where element.type == .window: renderer?.window(element, movedTo: .active)
        case (.minimize, _) where element.type == .window:
            renderer?.window(element, movedTo: .inactive)
            renderer?.window(element, movedTo: .background)
        case (.restore, _) where element.type == .window:
            renderer?.window(element, movedTo: .inactive)
            renderer?.window(element, movedTo: .active)
        case (.bringToFront, _) where element.type == .window:
            // The window taken to the front is the active one; every other window's scene resigns.
            for (other, _) in renderer?.roster.windows ?? [] where other !== element {
                renderer?.window(other, movedTo: .inactive)
            }
            renderer?.window(element, movedTo: .active)
        case (.close, _) where element.type == .popover:
            // As a tap beside it: UIKit takes the popover away, then tells its delegate.
            guard let popover = (element.native as? UIKitElement)?.shownPopover,
                  let presentation = popover.controller.presentationController
            else { throw DriverCannot(act, on: element) }
            popover.controller.dismiss(animated: false) { popover.presentationControllerDidDismiss(presentation) }
        case (.close, _) where element.type == .page:
            // The close button on the bar over the page, as the user presses it.
            guard let controller = (element.native as? UIKitElement)?.controller,
                  let close = Self.closeAction(on: controller)
            else { throw DriverCannot(act, on: element) }
            UIButton().sendAction(close)
        case (.close, _) where element.type == .window:
            // As the user swipes a window's scene away: it leaves the front, goes behind, then closes.
            renderer?.window(element, movedTo: .inactive)
            renderer?.window(element, movedTo: .background)
            renderer?.runtime.userClosed(element)
        case (.goBack, _) where element.type == .window || NodeType.pageTypes.contains(element.type):
            try performOnPages(act, on: element)
        case (.choose, _) where NodeType.pageTypes.contains(element.type):
            try performOnPages(act, on: element)
        case (.toggle, _) where element.type == .splitView:
            try performOnPages(act, on: element)
        case (.activate, _) where [.toolbarButton, .toolbarToggle].contains(element.type): try performOnPages(act, on: element)
        case (.activate, _) where [.menuItem, .menuToggle].contains(element.type):
            // The item as the menu UIKit is handed shows it, taken where it can be: a key command up the responder
            // chain to the window's root, an action to its handler.
            if let command = menuCommand(of: element) {
                if !command.attributes.contains(.disabled) { Self.windowRoot(of: element)?.chooseMenuEntry(command) }
                return
            }
            guard let action = menuAction(of: element) else { throw DriverCannot(act, on: element) }
            if !action.attributes.contains(.disabled) { UIButton().sendAction(action) }
        case (.tap(let count), _): try touch(element) { listening, view in Self.tap(listening, on: view, count: count) }
        case (.hold, _): try touch(element) { listening, view in Self.hold(listening, on: view) }
        case (.pan(let offset), _): try touch(element) { listening, view in Self.pan(listening, on: view, by: offset) }
        case (.sweep(let offset, let speed), _):
            try touch(element) { listening, _ in
                listening?.hand(.began, moved: .zero)
                listening?.hand(.changed, moved: offset)
                listening?.hand(.ended, moved: .zero, speed: speed)
            }
        case (.notch(let notches), _):
            try touch(element) { listening, _ in listening?.notched(notches) }
        case (.pinch(let scale, let share), _):
            try touch(element) { listening, view in Self.pinch(listening, on: view, by: scale, at: share) }
        case (.rotate(let degrees, _), _):
            try touch(element) { listening, view in Self.rotate(listening, on: view, by: degrees) }
        case (.pressDown(let point), _): try touch(element) { listening, view in pressDown(listening, on: view, at: point) }
        case (.drag(let point), _): try touch(element) { listening, _ in drag(listening, to: point) }
        case (.lift(let point), _): try touch(element) { listening, _ in lift(listening, at: point) }
        case (.hover(let point), _): try touch(element) { listening, view in Self.hover(listening, on: view, at: point) }
        case (.leave, _): try touch(element) { listening, view in Self.leave(listening, on: view) }
        case (.pickDate(let day), let picker as UIKitDatePickerView):
            picker.setDay(day)
            picker.sendActions(for: .valueChanged)
        case (.pickTime(let time), let picker as UIKitTimePickerView):
            picker.setTime(time)
            picker.sendActions(for: .valueChanged)
        case (.pickColor(let color), let picker as UIKitColorPickerView):
            // What the system's picker does as the user chooses: the well takes the color, then says it changed.
            picker.selectedColor = UIColor(stateUI: color.propValue)
            picker.sendActions(for: .valueChanged)
        case (.performAccessibilityAction(let name), let view?):
            // The action VoiceOver offers on what it meets of the view, run as VoiceOver runs it.
            if let action = Self.met(view).accessibilityCustomActions?.first(where: { $0.name == name }) {
                _ = action.actionHandler?(action)
            }
        case (.adjust(let step), let view?):
            // VoiceOver's swipe up or down: the step of what it meets.
            let met = Self.met(view)
            if step == .increment { met.accessibilityIncrement() } else { met.accessibilityDecrement() }
        default: throw DriverCannot(act, on: element)
        }
    }

    /// What a web view shows, by the address WebKit gives back: a document with no address of its own from the
    /// `data:` address holding it.
    private static func shown(by web: WebKitView) -> WebViewSource? {
        guard let address = web.url?.absoluteString else { return nil }
        return WebDocument.document(at: address).map { .html($0, baseURL: nil) } ?? .url(address)
    }

    /// Where the element's view stands in its window, as UIKit placed it.
    func place(of element: MountedElement) throws -> Rect {
        guard let view = (element.native as? UIKitElement)?.view else {
            throw DriverCannot("read where \(element.type.name) stands")
        }
        guard view.window != nil else { throw NotPlaced(element) }
        let frame = view.convert(view.bounds, to: nil)
        return Rect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        if element.type == .window { return try windowHolds(property, element) }
        if element.type == .sheet, property == .background {
            // A sheet shows its page, which stands on the ground it paints - the window's, where it says none.
            let page = element.children.first.map { $0.visiblePage ?? $0 }
            guard let view = (page?.native as? UIKitElement)?.controller?.view else {
                throw DriverCannot(reading: property, of: element)
            }
            return view.backgroundColor.map { Material.color(Self.color($0)).propValue }
        }
        if element.type == .popover, property == .isPresented {
            let controller = (element.native as? UIKitElement)?.shownPopover?.controller
            return (controller?.presentingViewController != nil && controller?.isBeingDismissed == false).propValue
        }
        if element.type == .marker { return try markerHolds(property, element) }
        if element.type == .textSpan { return try spanHolds(property, on: element) }
        if let map = (element.native as? UIKitElement)?.view as? UIKitMapView, let held = mapHolds(property, map) {
            return held
        }
        if property == .holdDuration, let time = (element.native as? UIKitElement)?.listening?.holdTime {
            return .number(time)
        }
        if let held = try pageHolds(property, element) { return held }
        let view = (element.native as? UIKitElement)?.view
        switch (property, view) {
        case (.selectedItems, let items as UIKitItemsView): return .strings(items.selectedForTesting)
        case (.selectionMode, let items as UIKitItemsView): return items.modeForTesting.propValue
        case (.text, let label as UIKitTextView): return (label.text ?? "").propValue
        case (.text, let link as UIKitLinkView): return (link.configuration?.attributedTitle.map { String($0.characters) } ?? "").propValue
        case (.text, let label as UIKitSelectableTextView): return (label.text ?? "").propValue
        // A label selects nothing; selectable words stand in a text view.
        case (.isSelectable, is UIKitTextView): return false.propValue
        case (.isSelectable, let label as UIKitSelectableTextView): return label.isSelectable.propValue
        case (.text, let field as any UIKitTextInputView): return field.words.propValue
        // A field's outline as its layer draws it: its color, its width, and its corners - none for a rectangle.
        case (.stroke, let field as any UIKitTextInputView):
            guard field.layer.borderWidth > 0 else { return nil }
            return field.layer.borderColor.map { Brush.solidColor(Self.color(UIColor(cgColor: $0))).propValue }
        case (.lineWidth, let field as any UIKitTextInputView): return Double(field.layer.borderWidth).propValue
        case (.shape, let field as any UIKitTextInputView):
            let radius = Double(field.layer.cornerRadius)
            return (radius == 0 ? ContainerShape.rectangle : .roundedRectangle(radius)).propValue
        case (.cursorPosition, let field as any UIKitTextInputView): return field.selection.start.propValue
        case (.selectionLength, let field as any UIKitTextInputView): return field.selection.length.propValue
        case (.placeholder, let field as UITextField): return field.attributedPlaceholder?.string.propValue
        case (.placeholderColor, let field as UITextField):
            guard let words = field.attributedPlaceholder, words.length > 0 else { return nil }
            return (words.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor).map { Self.color($0).propValue }
        case (.placeholder, let editor as UIKitTextEditorView): return editor.placeholder.propValue
        case (.isSpellCheckEnabled, let field as UITextField): return (field.spellCheckingType != .no).propValue
        case (.isSpellCheckEnabled, let editor as UITextView): return (editor.spellCheckingType != .no).propValue
        case (.isTextPredictionEnabled, let field as UITextField): return (field.autocorrectionType != .no).propValue
        case (.isTextPredictionEnabled, let editor as UITextView): return (editor.autocorrectionType != .no).propValue
        case (.isReadOnly, let editor as UIKitTextEditorView): return (!editor.isEditable && editor.isSelectable).propValue
        case (.isReadOnly, let field as any UIKitTextInputView): return field.typing.isReadOnly.propValue
        case (.maximumLength, let field as any UIKitTextInputView): return field.typing.maximumLength.map(\.propValue)
        case (.isPassword, let field as UITextField): return field.isSecureTextEntry.propValue
        case (.text, let button as UIKitButtonView): return (button.configuration?.title ?? "").propValue
        case (.isOn, let toggle as UIKitSwitchView): return toggle.isOn.propValue
        case (.isOn, let check as UIKitCheckView): return check.isOn.propValue
        case (.text, let check as UIKitCheckView): return (check.configuration?.title ?? "").propValue
        case (.text, let toggle as UIKitSwitchView): return (toggle.caption.text ?? "").propValue
        case (.value, let slider as UIKitSliderView): return Double(slider.value).propValue
        case (.minimum, let slider as UIKitSliderView): return Double(slider.minimumValue).propValue
        case (.maximum, let slider as UIKitSliderView): return Double(slider.maximumValue).propValue
        case (.value, let stepper as UIKitStepperView): return stepper.value.propValue
        case (.minimum, let stepper as UIKitStepperView): return stepper.minimumValue.propValue
        case (.maximum, let stepper as UIKitStepperView): return stepper.maximumValue.propValue
        case (.step, let stepper as UIKitStepperView): return stepper.stepValue.propValue
        case (.progress, let bar as UIKitProgressBarView): return Double(bar.bar.progress).propValue
        case (.isAnimating, let spinner as UIKitSpinnerView): return spinner.isAnimating.propValue
        case (.tint, let bar as UIKitProgressBarView): return bar.bar.progressTintColor.map { Self.color($0).propValue }
        case (.tint, let spinner as UIKitSpinnerView): return spinner.color.map { Self.color($0).propValue }
        case (.tint, let slider as UIKitSliderView): return slider.minimumTrackTintColor.map { Self.color($0).propValue }
        case (.tint, let toggle as UIKitSwitchView): return toggle.control.onTintColor.map { Self.color($0).propValue }
        case (.tint, let box as UIKitCheckView): return Self.color(box.tintColor).propValue
        case (.horizontalTextAlignment, let picker as UIKitPickerView):
            let alignments: [(UIControl.ContentHorizontalAlignment, TextAlignment)] = [
                (.leading, .start), (.center, .center), (.trailing, .end),
            ]
            return alignments.first { $0.0 == picker.contentHorizontalAlignment }?.1.propValue
        case (.tint, let picker as UIKitPickerView):
            return picker.configuration?.indicatorColorTransformer.map { Self.color($0(.label)).propValue }
        case (.selectedIndex, let picker as any UIKitChoosing): return (picker.chosen ?? -1).propValue
        case (.options, let picker as any UIKitChoosing): return picker.choices.propValue
        case (.placeholder, let picker as UIKitPickerView): return picker.title.propValue
        case (.date, let picker as UIKitDatePickerView): return picker.day.propValue
        case (.time, let picker as UIKitTimePickerView): return picker.time.propValue
        case (.color, let picker as UIKitColorPickerView): return picker.selectedColor.map { Self.color($0).propValue }
        case (.choosesOpacity, let picker as UIKitColorPickerView): return picker.supportsAlpha.propValue
        case (.minimumDate, let picker as UIKitDatePickerView): return picker.minimumDate.map(UIDatePicker.day(of:))?.propValue
        case (.maximumDate, let picker as UIKitDatePickerView): return picker.maximumDate.map(UIDatePicker.day(of:))?.propValue
        case (.isRefreshEnabled, let pulled as any UIKitRefreshing):
            return (pulled.refresh.scroller?.refreshControl != nil).propValue
        case (.isRefreshing, let pulled as any UIKitRefreshing):
            return (pulled.refresh.scroller?.refreshControl?.isRefreshing ?? false).propValue
        case (.edge, let shown?):
            let bar = sequence(first: shown, next: \.superview).lazy.compactMap { $0 as? UIKitBottomBarView }.first
            return bar?.shownEdge?.propValue
        case (.scrollOffset, let scroll as UIKitScrollView):
            return scroll.toolkitStanding.propValue
        case (.orientation, let scroll as UIKitScrollView): return scroll.orientation.propValue
        case (.source, let image as UIKitImageView): return image.image?.accessibilityIdentifier.map { .string($0) }
        case (.userAgent, let web as WebKitView): return web.customUserAgent.propValue
        case (.source, let web as WebKitView): return Self.shown(by: web)?.propValue
        // Shown: in a window, and neither it nor any view it stands in hidden.
        case (.isVisible, let view?):
            return (view.window != nil && sequence(first: view, next: \.superview).allSatisfy { !$0.isHidden }).propValue
        case (.opacity, let view?): return Double(view.alpha).propValue
        case (.isEnabled, let control as UIControl): return control.isEnabled.propValue
        // A switch stands beside its words: the switch itself takes the input.
        case (.isEnabled, let toggle as UIKitSwitchView): return toggle.control.isEnabled.propValue
        case (.submitLabel, let field as UITextField):
            let key: SubmitLabel? = switch field.returnKeyType {
            case .go: .go
            case .search: .search
            case .send: .send
            case .next: .next
            case .done: .done
            case .default: .default
            default: nil
            }
            return key?.propValue
        case (.showsClearButton, let field as UITextField): return (field.clearButtonMode != .never).propValue
        // Ignoring input: UIKit passes over the view and all in it as it finds what a touch lands on.
        case (.ignoresInput, let view?): return (!view.isUserInteractionEnabled).propValue
        case (.layoutDirection, let view?):
            return (view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? LayoutDirection.rightToLeft : .leftToRight)
                .propValue
        case (.isEnabled, let label as UILabel): return label.isEnabled.propValue
        case (.isEnabled, let editor as UITextView): return (editor.isEditable || editor.isSelectable).propValue
        // A view that is no control holds whether it answers as VoiceOver meets it.
        case (.isEnabled, let view?): return (!view.accessibilityTraits.contains(.notEnabled)).propValue
        case (.padding, let button as UIButton):
            guard let insets = button.configuration?.contentInsets else { return nil }
            return Insets(start: insets.leading, top: insets.top, end: insets.trailing, bottom: insets.bottom).propValue
        case (.padding, let label as UIKitTextView):
            let padding = label.padding
            let rightToLeft = label.effectiveUserInterfaceLayoutDirection == .rightToLeft
            return Insets(
                start: rightToLeft ? padding.right : padding.left, top: padding.top,
                end: rightToLeft ? padding.left : padding.right, bottom: padding.bottom).propValue
        case (_, let view?):
            if let held = try Self.viewHolds(property, view, element.native as? UIKitElement) { return held }
            throw DriverCannot(reading: property, of: element)
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// The root of the window `element` stands in, which offers the window's key commands.
    static func windowRoot(of element: MountedElement) -> UIKitRootViewController? {
        var each: MountedElement? = element
        while let current = each, (current.native as? UIKitElement)?.view?.window == nil { each = current.parent }
        return (each?.native as? UIKitElement)?.view?.window?.rootViewController as? UIKitRootViewController
    }
}

/// The host's log, line by line, as the driver hears it.
final class UIKitLogLines: @unchecked Sendable {
    private(set) var lines: [String] = []

    /// Listens to the host's log from now on.
    @MainActor func listen() {
        lines = []
        UIKitRenderer.log = HostLog(host: "UIKit") { [self] line in
            lines.append(line)
            UIKitTestRunner.say(line.hasSuffix("\n") ? String(line.dropLast()) : line)
        }
    }
}
