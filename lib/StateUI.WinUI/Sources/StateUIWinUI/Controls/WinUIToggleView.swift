// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A control that is on or off - a WinUI `ToggleSwitch`, `CheckBox` or `RadioButton` - whose turn reaches Swift
/// through the relay.
/// Design: docs/design/platforms/winui/controls.md#on-or-off
@MainActor
class WinUIToggleView: WinUIView {
    /// What the control does when the user turns it.
    var onToggled: ((Bool) -> Void)?

    /// Whether the control stands on.
    var isOn: Bool { stateui_winui_toggle_is_on(handle) }

    /// Turns the control on or off.
    func setOn(_ on: Bool) {
        stateui_winui_toggle_set_on(handle, on)
    }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    /// What the control is drawn over; nil for WinUI's own.
    func setBackground(_ value: HostValue?) {
        WinUIBrush(value).withRelayBrush { stateui_winui_toggle_set_background(handle, $0) }
    }

    override func detach() {
        super.detach()
        onToggled = nil
    }
}
