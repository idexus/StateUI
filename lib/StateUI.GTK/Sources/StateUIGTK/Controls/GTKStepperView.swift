// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A Stepper: a `GtkSpinButton` - its number, which the user can type, and the buttons and the arrow keys moving
/// it a step, Page Up ten - kept inside its range. Words that say no number leave the number where it was.
/// Design: docs/design/platforms/gtk/controls.md#a-stepper
@MainActor
final class GTKStepperView: GTKView {
    /// What the stepper does when its value moves, handed the value it stands at.
    var onValueChanged: ((Double) -> Void)?

    init() {
        super.init { _ in gtk_spin_button_new_with_range(0, 100, 1) }
        connect("value-changed") { _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKStepperView else { return }
                view.onValueChanged?(view.value)
            }
        }
        connectSignal(UnsafeMutableRawPointer(widget), "input", number: number) { button, number, _ in
            number?.pointee = GTKStepperView.read(OpaquePointer(button!))
            return 1
        }
    }

    private var button: OpaquePointer { widget.opaque }

    /// The number the box's words say, read as GTK reads them; where they say none, the number it stands at.
    /// Design: docs/design/platforms/gtk/controls.md#a-stepper
    nonisolated private static func read(_ button: OpaquePointer) -> Double {
        let words = gtk_editable_get_text(button)
        var end: UnsafeMutablePointer<CChar>?
        let number = g_strtod(words, &end)
        let readable = end?.pointee == 0 && !String(cString: words!).allSatisfy(\.isWhitespace)
        return readable ? number : gtk_spin_button_get_value(button)
    }

    /// The number the stepper stands at.
    var value: Double { gtk_spin_button_get_value(button) }

    /// The range and the step, then the value: `value` where `writeValue`, else the one it stands at, kept inside
    /// the range; written with as many decimals as they take.
    func apply(value: Double?, writeValue: Bool, minimum: Double, maximum: Double, step: Double) {
        let kept = writeValue ? value ?? self.value : self.value
        let (low, high) = (Swift.min(minimum, maximum), Swift.max(minimum, maximum))
        let step = step.isFinite && step > 0 ? step : 1
        gtk_spin_button_set_digits(button, guint(StepArithmetic.decimals(of: [step, low, high, kept])))
        gtk_spin_button_set_range(button, low, high)
        gtk_spin_button_set_increments(button, step, step * 10)
        gtk_spin_button_set_value(button, kept)
    }

    override func detach() {
        super.detach()
        onValueChanged = nil
    }
}
