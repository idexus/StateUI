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

    /// The range and the step, then `value`, kept inside the range; written with as many decimals as they take.
    func apply(value: Double, minimum: Double, maximum: Double, step: Double) {
        let (low, high) = ValueArithmetic.range(minimum, maximum)
        let step = ValueArithmetic.step(step)
        stateui_winui_stepper_set(
            handle, value, low, high, step, Int32(ValueArithmetic.decimals(of: [step, low, high, value])))
    }
}
