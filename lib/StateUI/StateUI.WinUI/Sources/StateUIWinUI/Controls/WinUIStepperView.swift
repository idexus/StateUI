// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A Stepper: WinUI's `NumberBox`, its spin buttons beside its number.
@MainActor
final class WinUIStepperView: WinUIValueView {
    init() {
        super.init { number in stateui_winui_stepper_make(number) }
    }

    /// The number it shows.
    var value: Double { stateui_winui_stepper_value(handle) }

    /// The value it stood at before the user's step, and the step it moves by.
    private var shown = 0.0
    private var step = 1.0

    /// The range and the step, then `value`, kept inside the range; written with as many decimals as they take.
    func apply(value: Double, minimum: Double, maximum: Double, step: Double) {
        let (low, high) = ValueArithmetic.range(minimum, maximum)
        let step = ValueArithmetic.step(step)
        self.step = step
        shown = min(max(value, low), high)
        stateui_winui_stepper_set(
            handle, value, low, high, step, Int32(ValueArithmetic.decimals(of: [step, low, high, value])))
    }

    /// Where the user's step to `reported` lands: on its decimals (`ValueArithmetic.landed`).
    func landed(_ reported: Double) -> Double {
        shown = ValueArithmetic.landed(reported, from: shown, step: step)
        return shown
    }
}
