// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A Switch: a WinUI `ToggleSwitch`, whose turn reaches Swift through the relay.
@MainActor
final class WinUISwitchView: WinUIView {
    /// What the switch does when it turns.
    var onToggled: ((Bool) -> Void)?

    init() {
        super.init { number in stateui_winui_switch_make(number) }
    }

    /// Whether the switch stands on.
    var isOn: Bool { stateui_winui_switch_is_on(handle) }

    /// Turns the switch on or off.
    func setOn(_ on: Bool) {
        stateui_winui_switch_set_on(handle, on)
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func detach() {
        super.detach()
        onToggled = nil
    }
}
