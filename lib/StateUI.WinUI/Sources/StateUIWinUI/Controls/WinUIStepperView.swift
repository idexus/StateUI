// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A Stepper: WinUI's `NumberBox`, its spin buttons beside its number.
@MainActor
final class WinUIStepperView: WinUIValueView {
    init() {
        super.init { number in stateui_winui_stepper_make(number) }
    }

    /// The number it shows.
    var value: Double { stateui_winui_stepper_value(handle) }

    /// The range, the step, then the value: `value` where `writeValue`, else the one it shows, kept inside the range.
    func apply(value: Double?, writeValue: Bool, minimum: Double, maximum: Double, step: Double) {
        let kept = writeValue ? value ?? self.value : self.value
        stateui_winui_stepper_set(
            handle, kept, minimum, maximum, step, Self.decimals(of: [step, minimum, maximum, kept]))
    }

    /// The decimals the numbers need to be written whole, six at most.
    nonisolated static func decimals(of numbers: [Double]) -> Int32 {
        numbers.filter(\.isFinite).map { number in
            var digits: Int32 = 0
            var shifted = abs(number)
            while digits < 6, abs(shifted - shifted.rounded()) > 1e-9 {
                shifted *= 10
                digits += 1
            }
            return digits
        }.max() ?? 0
    }
}
