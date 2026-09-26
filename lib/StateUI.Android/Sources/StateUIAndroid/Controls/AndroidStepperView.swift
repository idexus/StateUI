// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Stepper: Android has none, so its own buttons side by side in a `LinearLayout` - one a step down,
/// one a step up - each off at its end of the range.
/// Design: docs/design/platforms/android/controls.md#a-stepper
@MainActor
final class AndroidStepperView: AndroidView {
    /// What the stepper does when the user steps it, handed the value it stepped to.
    var onValueChanged: ((Double) -> Void)?

    private let down = AndroidButtonView()
    private let up = AndroidButtonView()

    /// The way down and the way up.
    var buttons: (down: AndroidButtonView, up: AndroidButtonView) { (down, up) }

    private(set) var value = 0.0
    private var lowest = 0.0
    private var highest = 100.0
    private var step = 1.0
    private var enabled = true

    init() {
        super.init { _ in Java.new(JavaAPI.linearLayout, JavaAPI.newLinearLayout, .object(AndroidRenderer.context)) }
        for (button, caption) in [(down, "−"), (up, "+")] {
            button.setText(caption)
            button.setLeastSize(width: pixels(48), height: pixels(48))
            Java.call(reference, JavaAPI.addView, .object(button.reference), .int(-2), .int(-2))
        }
        down.onClicked = { [weak self] in self?.stepped(by: -1) }
        up.onClicked = { [weak self] in self?.stepped(by: 1) }
    }

    /// The range, the step and whether it can be stepped - the stepper itself on or off, as its buttons are - then
    /// the value, held in the range.
    func apply(value: Double, minimum: Double, maximum: Double, step: Double, enabled: Bool) {
        (lowest, highest) = ValueArithmetic.range(minimum, maximum)
        self.step = ValueArithmetic.step(step)
        self.enabled = enabled
        self.value = min(max(value, lowest), highest)
        setEnabled(enabled)
        showEnds()
    }

    /// The user stepped once, down or up.
    private func stepped(by direction: Double) {
        let stepped = min(max(value + direction * step, lowest), highest)
        guard stepped != value else { return }

        value = stepped
        showEnds()
        onValueChanged?(stepped)
    }

    /// Each button is on while the stepper is and its way is not at the range's end.
    private func showEnds() {
        down.setEnabled(enabled && value > lowest)
        up.setEnabled(enabled && value < highest)
    }

    override func detach() {
        super.detach()
        onValueChanged = nil
    }
}
