// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A Switch: a `GtkSwitch`.
@MainActor
final class GTKSwitchView: GTKToggleView {
    init() {
        super.init({ gtk_switch_new() }, turning: "active")
    }

    override var isOn: Bool { gtk_switch_get_active(widget.opaque) != 0 }

    /// The track while the switch is on.
    override var accent: String? { ":checked" }

    /// None: GTK paints a switch's box as its track, which a colour there would recolour - its register's
    /// `notPlanned`.
    override func setBackground(_ value: HostValue?) {}

    override func setOn(_ on: Bool) {
        gtk_switch_set_active(widget.opaque, on ? 1 : 0)
    }
}
