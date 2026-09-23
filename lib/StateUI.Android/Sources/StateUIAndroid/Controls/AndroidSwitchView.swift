// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A Switch: an `android.widget.Switch` whose flip reaches Swift through its `StateUIListener`.
@MainActor
final class AndroidSwitchView: AndroidView {
    /// What the switch does when the user turns it.
    var onToggled: ((Bool) -> Void)?

    init() {
        super.init { _ in Java.new(JavaAPI.switchView, JavaAPI.newSwitch, .object(AndroidRenderer.context)) }
        listen(JavaAPI.setOnCheckedChangeListener)
    }

    /// Whether the switch stands on.
    var isOn: Bool { Java.callBool(reference, JavaAPI.isChecked) }

    /// Turns the switch on or off.
    func setOn(_ on: Bool) {
        Java.call(reference, JavaAPI.setChecked, .bool(on))
    }

    override func detach() {
        super.detach()
        onToggled = nil
    }
}
