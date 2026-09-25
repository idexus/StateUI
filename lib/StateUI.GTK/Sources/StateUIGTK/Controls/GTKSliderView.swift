// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A Slider: a horizontal `GtkScale` over the range, drawing no number and rounding nothing the hand sets.
/// Design: docs/design/platforms/gtk/controls.md#a-slider-and-its-range
@MainActor
final class GTKSliderView: GTKView {
    /// What the slider does when its value moves, handed the value it stands at.
    var onValueChanged: ((Double) -> Void)?

    /// The range's ends, the lower first.
    private(set) var minimum = 0.0
    private(set) var maximum = 1.0

    init() {
        super.init { _ in gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, 0, 1, 0.01) }
        gtk_scale_set_draw_value(widget.of(GtkScale.self), 0)
        gtk_range_set_round_digits(range, -1)
        connect("value-changed") { _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKSliderView else { return }
                view.onValueChanged?(view.value)
            }
        }
    }

    private var range: UnsafeMutablePointer<GtkRange> { widget.of(GtkRange.self) }

    /// The value the thumb stands at.
    var value: Double { gtk_range_get_value(range) }

    /// The range, then the value: `value` where `writeValue`, else the one the thumb stands at, kept inside the range.
    func apply(value: Double?, writeValue: Bool, minimum: Double, maximum: Double) {
        let kept = writeValue ? value ?? self.value : self.value
        self.minimum = Swift.min(minimum, maximum)
        self.maximum = Swift.max(minimum, maximum)
        let span = self.maximum - self.minimum
        gtk_range_set_range(range, self.minimum, self.maximum)
        gtk_range_set_increments(range, span / 100, span / 10)
        gtk_range_set_value(range, kept)
    }

    override func detach() {
        onValueChanged = nil
    }
}
