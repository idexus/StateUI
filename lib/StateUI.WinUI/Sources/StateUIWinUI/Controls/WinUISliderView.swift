// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A Slider: a WinUI `Slider` over the range, stepping by a ten-thousandth of it.
@MainActor
final class WinUISliderView: WinUIView {
    /// What the slider does when its value moves, handed the value it stands at.
    var onValueChanged: ((Double) -> Void)?

    /// The range's ends, the lower first.
    private(set) var minimum = 0.0
    private(set) var maximum = 1.0

    init() {
        super.init { number in stateui_winui_slider_make(number) }
    }

    /// The value the thumb stands at.
    var value: Double { stateui_winui_slider_value(handle) }

    /// The range, then the value: `value` where `writeValue`, else the one the thumb stands at, kept inside the range.
    func apply(value: Double?, writeValue: Bool, minimum: Double, maximum: Double) {
        let kept = writeValue ? value ?? self.value : self.value
        self.minimum = Swift.min(minimum, maximum)
        self.maximum = Swift.max(minimum, maximum)
        stateui_winui_slider_set(handle, kept, minimum, maximum)
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func detach() {
        onValueChanged = nil
    }
}
