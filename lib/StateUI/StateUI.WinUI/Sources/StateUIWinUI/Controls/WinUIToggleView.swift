// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A control that is on or off - a WinUI `ToggleSwitch` or `CheckBox` - whose turn reaches Swift through the relay.
/// Design: docs/design/platforms/winui/controls.md#on-or-off
@MainActor
class WinUIToggleView: WinUIView {
    override var takesDirection: Bool { true }

    /// What the control does when the user turns it.
    var onToggled: ((Bool) -> Void)?

    /// Whether the control stands on.
    var isOn: Bool { stateui_winui_toggle_is_on(handle) }

    /// Turns the control on or off.
    func setOn(_ on: Bool) {
        stateui_winui_toggle_set_on(handle, on)
    }

    /// The words the control says - a switch's header over its track, a check box's words beside its box - and
    /// their color; nil for the platform's.
    func setWords(_ words: String, color: HostValue?) {
        let argb = color?.argb
        stateui_winui_toggle_set_words(handle, words, argb != nil, argb ?? 0)
    }

    /// The words the control says now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }

    override func detach() {
        super.detach()
        onToggled = nil
    }
}
