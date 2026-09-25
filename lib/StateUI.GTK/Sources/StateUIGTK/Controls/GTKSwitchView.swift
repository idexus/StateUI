// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A Switch: a `GtkSwitch`, whose turn is heard from its `active` property.
@MainActor
final class GTKSwitchView: GTKView {
    /// What the switch does when it turns.
    var onToggled: ((Bool) -> Void)?

    init() {
        super.init { _ in gtk_switch_new() }
        notify("active") { _, _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKSwitchView else { return }
                view.onToggled?(view.isOn)
            }
        }
    }

    /// Whether the switch stands on.
    var isOn: Bool { gtk_switch_get_active(widget.opaque) != 0 }

    /// Turns the switch on or off.
    func setOn(_ on: Bool) {
        gtk_switch_set_active(widget.opaque, on ? 1 : 0)
    }

    override func detach() {
        onToggled = nil
    }
}
