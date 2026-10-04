// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A Slider: a WinUI `Slider` over the range, stepping by a ten-thousandth of it.
@MainActor
final class WinUISliderView: WinUIValueView {
    /// The range's ends, the lower first.
    private(set) var minimum = 0.0
    private(set) var maximum = 1.0

    init() {
        super.init { number in stateui_winui_slider_make(number) }
    }

    /// The value the thumb stands at.
    var value: Double { stateui_winui_slider_value(handle) }

    /// How far an arrow key, Page Up and a drag move the thumb, as WinUI holds them.
    var steps: (key: Double, page: Double, drag: Double) {
        var values = [0.0, 0.0, 0.0]
        stateui_winui_slider_steps(handle, &values)
        return (values[0], values[1], values[2])
    }

    /// The range, then `value`, kept inside it.
    func apply(value: Double, minimum: Double, maximum: Double) {
        (self.minimum, self.maximum) = ValueArithmetic.range(minimum, maximum)
        let steps = ValueArithmetic.sliderSteps(lower: self.minimum, upper: self.maximum)
        // A drag lands on a ten-thousandth of the range.
        let drag = self.maximum > self.minimum ? (self.maximum - self.minimum) / 10000 : 1
        stateui_winui_slider_set(handle, value, self.minimum, self.maximum, steps.key, steps.page, drag)
    }
}
