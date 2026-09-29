// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A control that holds one number the user moves - a WinUI `Slider` or `NumberBox` - whose move reaches Swift
/// through the relay.
@MainActor
class WinUIValueView: WinUIView {
    /// What the control does when its value moves, handed the value it stands at.
    var onValueChanged: ((Double) -> Void)?

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func detach() {
        super.detach()
        onValueChanged = nil
    }
}
