// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A control that is on or off: one of Android's `CompoundButton`s - a `TextView`, so one with words of
/// its own shows them - whose flip reaches Swift through its `StateUIListener`.
@MainActor
class AndroidToggleView: AndroidTextView {
    /// What the control does when the user turns it.
    var onToggled: ((Bool) -> Void)?

    override init(_ make: (_ number: Int64) -> JavaObject) {
        super.init(make)
        listen(JavaAPI.setOnCheckedChangeListener)
    }

    /// Whether the control stands on.
    var isOn: Bool { Java.callBool(reference, JavaAPI.isChecked) }

    /// Turns the control on or off.
    func setOn(_ on: Bool) {
        Java.call(reference, JavaAPI.setChecked, .bool(on))
    }

    override func detach() {
        super.detach()
        onToggled = nil
    }
}
