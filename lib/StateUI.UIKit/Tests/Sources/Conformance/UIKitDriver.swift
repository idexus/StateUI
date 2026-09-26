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
    let cannot: [String: String] = [:]

    /// What the families ask of a driver that UIKit's has no path for yet says so, and stays empty in UIKit's column
    /// with why, rather than failing.
    func reason(cannot ability: String) -> String? {
        cannot[ability] ?? "UIKit's driver has no path for it yet"
    }

    /// The host the driver started last.
    private(set) var renderer: UIKitRenderer?

    var register: HostRegister { UIKitRealization.register }

    func start(clock: TestClock?, reducesMotion: Bool, _ page: @escaping @Sendable () -> any Page) -> MountedTree {
        finish()
        let renderer = UIKitRenderer.running(clock: clock, reducesMotion: reducesMotion, page)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    /// Ends the host the driver started last.
    func finish() {
        renderer?.finish()
        renderer = nil
    }

    func step() {
        guard let renderer else { return }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        _ = renderer.runtime.core.runJobs()
        renderer.runtime.pump.turn()
        renderer.layOut()
        if renderer.frameClock.held { renderer.frame() }
    }

    func turn() {
        renderer?.runtime.pump.turn()
        renderer?.layOut()
    }

    func frame() {
        renderer?.frame()
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        let view = (element.native as? UIKitElement)?.view
        switch (act, view) {
        case (.activate, let button as UIKitButtonView): button.sendActions(for: .primaryActionTriggered)
        case (.type(let words), let editor as UIKitTextEditorView):
            // UIKit asks the editor's delegate before any change a key makes.
            let whole = NSRange(location: 0, length: editor.text.utf16.count)
            guard editor.isEditable,
                  editor.delegate?.textView?(editor, shouldChangeTextIn: whole, replacementText: words) ?? true
            else { return }
            editor.text = words
            editor.delegate?.textViewDidChange?(editor)
        case (.type(let words), let field as UITextField & UIKitInputView):
            let whole = NSRange(location: 0, length: field.words.utf16.count)
            guard field.delegate?.textField?(field, shouldChangeCharactersIn: whole, replacementString: words) ?? true
            else { return }
            field.text = words
            field.sendActions(for: .editingChanged)
        case (.submit, let field as UITextField & UIKitInputView): _ = field.delegate?.textFieldShouldReturn?(field)
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
        case (.pickDate(let day), let picker as UIKitDateTimePickerView):
            picker.apply(value: day.propValue.numbers, minimum: nil, maximum: nil)
            picker.sendActions(for: .valueChanged)
        case (.pickTime(let time), let picker as UIKitDateTimePickerView):
            picker.apply(value: time.propValue.numbers, minimum: nil, maximum: nil)
            picker.sendActions(for: .valueChanged)
        default: throw DriverCannot(act, on: element)
        }
    }

    /// A day a date picker holds, as the tree says one.
    private static func day(_ date: Date) -> HostValue {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return CalendarDate(year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1).propValue
    }

    func held(_ property: Prop, on element: MountedElement) throws -> HostValue? {
        let view = (element.native as? UIKitElement)?.view
        switch (property, view) {
        case (.text, let label as UIKitLabelView): return (label.text ?? "").propValue
        case (.text, let field as any UIKitInputView): return field.words.propValue
        case (.cursorPosition, let field as any UIKitInputView): return field.selection.start.propValue
        case (.selectionLength, let field as any UIKitInputView): return field.selection.length.propValue
        case (.placeholder, let field as UITextField): return field.attributedPlaceholder?.string.propValue
        case (.placeholder, let editor as UIKitTextEditorView): return editor.placeholder.propValue
        case (.isSpellCheckEnabled, let field as UITextField): return (field.spellCheckingType != .no).propValue
        case (.isSpellCheckEnabled, let editor as UITextView): return (editor.spellCheckingType != .no).propValue
        case (.isTextPredictionEnabled, let field as UITextField): return (field.autocorrectionType != .no).propValue
        case (.isTextPredictionEnabled, let editor as UITextView): return (editor.autocorrectionType != .no).propValue
        case (.isReadOnly, let editor as UIKitTextEditorView): return (!editor.isEditable).propValue
        case (.isReadOnly, let field as any UIKitInputView): return field.typing.isReadOnly.propValue
        case (.maximumLength, let field as any UIKitInputView): return field.typing.maximumLength.map(\.propValue)
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
        case (.progress, let bar as UIKitProgressBarView): return Double(bar.progress).propValue
        case (.isRunning, let spinner as UIKitActivityIndicatorView): return spinner.isAnimating.propValue
        case (.tint, let bar as UIKitProgressBarView): return bar.progressTintColor.map { Self.color($0).propValue }
        case (.tint, let spinner as UIKitActivityIndicatorView): return spinner.color.map { Self.color($0).propValue }
        case (.tint, let slider as UIKitSliderView): return slider.minimumTrackTintColor.map { Self.color($0).propValue }
        case (.selectedIndex, let picker as UIKitPickerView): return picker.chosen.map(\.propValue)
        case (.options, let picker as UIKitPickerView): return picker.choices.propValue
        case (.title, let picker as UIKitPickerView): return picker.title.propValue
        case (.date, let picker as UIKitDateTimePickerView):
            return CalendarDate(propValue: .numbers(picker.lanes))?.propValue
        case (.time, let picker as UIKitDateTimePickerView):
            return ClockTime(propValue: .numbers(picker.lanes))?.propValue
        case (.minimumDate, let picker as UIKitDateTimePickerView): return picker.minimumDate.map(Self.day)
        case (.maximumDate, let picker as UIKitDateTimePickerView): return picker.maximumDate.map(Self.day)
        case (.scrollOffset, let scroll as UIKitScrollView):
            return Point(x: scroll.scroller.contentOffset.x, y: scroll.scroller.contentOffset.y).propValue
        case (.orientation, let scroll as UIKitScrollView): return scroll.orientation.propValue
        case (.isVisible, let view?): return (!view.isHidden).propValue
        case (.opacity, let view?): return Double(view.alpha).propValue
        case (.isEnabled, let control as UIControl): return control.isEnabled.propValue
        case (_, let view?):
            if let held = try Self.viewHolds(property, view, element.native as? UIKitElement) { return held }
            throw DriverCannot(reading: property, of: element)
        default: throw DriverCannot(reading: property, of: element)
        }
    }
}
