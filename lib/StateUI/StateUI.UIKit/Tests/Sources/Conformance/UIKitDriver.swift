// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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
        for shape in ["Ellipse", "Line", "Path", "Polygon", "Polyline", "Rectangle"] {
            for member in ["contentMode", "geometryTransform"] {
                none["read \(member) of \(shape)"] =
                    "StateUI places and moves a shape's figure into its layer's path, which holds no \(member); its drawing proves it"
            }
        }
        for layout in ["Grid", "HStack", "VStack", "ZStack", "ScrollView"] {
            none["read shape of \(layout)"] =
                "UIKit holds a layout's outline as its layer's path, no shape; its drawing proves it"
            for member in ["padding", "avoidsSafeArea"] {
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

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        finish()
        forgetWhatIsKept()
        written.listen()
        let renderer = UIKitRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    /// Runs `application` on a new host, as the next launch does: what the last kept stands.
    func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree {
        finish()
        written.listen()
        let renderer = UIKitRenderer.running(clock: clock, application: application)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func forgetWhatIsKept() {
        TestScene.forgetWhatIsKept()
    }

    /// A menu item's action in the menu UIKit is handed now - the menu bar's, or the context menu of the view it
    /// stands under.
    func menuAction(of element: MountedElement) -> UIAction? {
        _ = renderer?.menuBar
        var holder = element.parent
        while let each = holder, (each.native as? UIKitElement)?.view == nil { holder = each.parent }
        _ = (holder?.native as? UIKitElement)?.builtContextMenu
        return (element.native as? UIKitElement)?.menuAction
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
        renderer?.finish()
        renderer = nil
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
        case (.tap(let count), let map as UIKitMapView):
            // A tap on a map is the map's, and the view's where it hears taps too.
            try touch(element) { listening, view in Self.tap(listening, on: view, count: count) }
            map.tap(at: CGPoint(x: map.bounds.midX, y: map.bounds.midY))
        case (.activate, _) where element.parent?.type == .itemsView:
            guard let items = (element.parent?.native as? UIKitElement)?.view as? UIKitItemsView,
                  case .manual(let identity) = element.id
            else { throw DriverCannot(act, on: element) }
            items.activateForTesting(identity)
        case (.choose(let place), let items as UIKitItemsView): items.chooseForTesting(place)
        case (.scroll(let target), let items as UIKitItemsView): items.scrollForTesting(to: target)
        case (.activate, let button as UIKitButtonView): button.sendActions(for: .primaryActionTriggered)
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
            toggle.setOn(!toggle.isOn, animated: false)
            toggle.sendActions(for: .valueChanged)
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
        case (.scroll(let target), let scroll as UIKitScrollView):
            // A finger takes the scroller, moves it there, and lets go without a throw.
            scroll.scrollViewWillBeginDragging(scroll.scroller)
            scroll.scroller.contentOffset = CGPoint(x: target.x, y: target.y)
            scroll.scrollViewDidEndDragging(scroll.scroller, willDecelerate: false)
        case (.choose(let place), let picker as UIKitPickerView): picker.userChose(place)
        case (.endContent, let web as UIKitWebView):
            // As WebKit tells it when the page's process dies.
            web.navigationDelegate?.webViewWebContentProcessDidTerminate?(web)
        case (.focus, let view?):
            // A finger in a field: it takes the keyboard.
            guard let focusable = Self.focusable(in: view) else { throw DriverCannot(act, on: element) }
            focusable.becomeFirstResponder()
            renderer?.focusMoved()
        case (.answer(let caption, let words), _):
            guard renderer?.actToolkit.showing?.press(caption, typing: words) == true else {
                throw DriverCannot("press \(caption): no question shows it")
            }
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
        case (.activate, _) where element.type == .toolbarItem: try performOnPages(act, on: element)
        case (.activate, _) where element.type == .menuItem:
            // The item as the menu UIKit is handed shows it, taken where it can be.
            guard let action = menuAction(of: element) else { throw DriverCannot(act, on: element) }
            if !action.attributes.contains(.disabled) { UIButton().sendAction(action) }
        case (.tap(let count), _): try touch(element) { listening, view in Self.tap(listening, on: view, count: count) }
        case (.pan(let offset), _): try touch(element) { listening, view in Self.pan(listening, on: view, by: offset) }
        case (.pinch(let scale, let share), _):
            try touch(element) { listening, view in Self.pinch(listening, on: view, by: scale, at: share) }
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
        default: throw DriverCannot(act, on: element)
        }
    }

    /// What a web view shows, by the address WebKit gives back: a document with no address of its own from the
    /// `data:` address holding it.
    private static func shown(by web: UIKitWebView) -> WebViewSource? {
        guard let address = web.url?.absoluteString else { return nil }
        return WebDocument.document(at: address).map { .html($0, baseURL: nil) } ?? .url(address)
    }

    /// Where the element's view stands in its window, as UIKit placed it.
    func place(of element: MountedElement) throws -> Rect {
        guard let view = (element.native as? UIKitElement)?.view, view.window != nil else {
            throw DriverCannot("read where \(element.type.name) stands")
        }
        let frame = view.convert(view.bounds, to: nil)
        return Rect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        if element.type == .window { return try windowHolds(property, element) }
        if element.type == .marker { return try markerHolds(property, element) }
        if let map = (element.native as? UIKitElement)?.view as? UIKitMapView, let held = mapHolds(property, map) {
            return held
        }
        if let held = try pageHolds(property, element) { return held }
        let view = (element.native as? UIKitElement)?.view
        switch (property, view) {
        case (.selectedItems, let items as UIKitItemsView): return .strings(items.selectedForTesting)
        case (.selectionMode, let items as UIKitItemsView): return items.modeForTesting.propValue
        case (.text, let label as UIKitTextView): return (label.text ?? "").propValue
        case (.text, let field as any UIKitTextInputView): return field.words.propValue
        case (.cursorPosition, let field as any UIKitTextInputView): return field.selection.start.propValue
        case (.selectionLength, let field as any UIKitTextInputView): return field.selection.length.propValue
        case (.placeholder, let field as UITextField): return field.attributedPlaceholder?.string.propValue
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
        case (.value, let slider as UIKitSliderView): return Double(slider.value).propValue
        case (.minimum, let slider as UIKitSliderView): return Double(slider.minimumValue).propValue
        case (.maximum, let slider as UIKitSliderView): return Double(slider.maximumValue).propValue
        case (.value, let stepper as UIKitStepperView): return stepper.value.propValue
        case (.minimum, let stepper as UIKitStepperView): return stepper.minimumValue.propValue
        case (.maximum, let stepper as UIKitStepperView): return stepper.maximumValue.propValue
        case (.step, let stepper as UIKitStepperView): return stepper.stepValue.propValue
        case (.progress, let bar as UIKitProgressBarView): return Double(bar.bar.progress).propValue
        case (.isAnimating, let spinner as UIKitActivityIndicatorView): return spinner.isAnimating.propValue
        case (.tint, let bar as UIKitProgressBarView): return bar.bar.progressTintColor.map { Self.color($0).propValue }
        case (.tint, let spinner as UIKitActivityIndicatorView): return spinner.color.map { Self.color($0).propValue }
        case (.tint, let slider as UIKitSliderView): return slider.minimumTrackTintColor.map { Self.color($0).propValue }
        case (.selectedIndex, let picker as UIKitPickerView): return picker.chosen.map(\.propValue)
        case (.options, let picker as UIKitPickerView): return picker.choices.propValue
        case (.placeholder, let picker as UIKitPickerView): return picker.title.propValue
        case (.date, let picker as UIKitDatePickerView): return picker.day.propValue
        case (.time, let picker as UIKitTimePickerView): return picker.time.propValue
        case (.minimumDate, let picker as UIKitDatePickerView): return picker.minimumDate.map(UIDatePicker.day(of:))?.propValue
        case (.maximumDate, let picker as UIKitDatePickerView): return picker.maximumDate.map(UIDatePicker.day(of:))?.propValue
        case (.scrollOffset, let scroll as UIKitScrollView):
            return Point(x: scroll.scroller.contentOffset.x, y: scroll.scroller.contentOffset.y).propValue
        case (.orientation, let scroll as UIKitScrollView): return scroll.orientation.propValue
        case (.source, let image as UIKitImageView): return image.image?.accessibilityIdentifier.map { .string($0) }
        case (.userAgent, let web as UIKitWebView): return web.customUserAgent.propValue
        case (.source, let web as UIKitWebView): return Self.shown(by: web)?.propValue
        // Shown: in a window, and neither it nor any view it stands in hidden.
        case (.isVisible, let view?):
            return (view.window != nil && sequence(first: view, next: \.superview).allSatisfy { !$0.isHidden }).propValue
        case (.opacity, let view?): return Double(view.alpha).propValue
        case (.isEnabled, let control as UIControl): return control.isEnabled.propValue
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
        case (.padding, let button as UIButton):
            guard let insets = button.configuration?.contentInsets else { return nil }
            return Insets(left: insets.leading, top: insets.top, right: insets.trailing, bottom: insets.bottom).propValue
        case (.padding, let label as UIKitTextView):
            return Insets(left: label.padding.left, top: label.padding.top, right: label.padding.right, bottom: label.padding.bottom).propValue
        case (_, let view?):
            if let held = try Self.viewHolds(property, view, element.native as? UIKitElement) { return held }
            throw DriverCannot(reading: property, of: element)
        default: throw DriverCannot(reading: property, of: element)
        }
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
