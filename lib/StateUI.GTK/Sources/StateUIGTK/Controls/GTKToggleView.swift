// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A control that stands on or off - a switch, a check box, a radio button - and the turn the user makes, told
/// through one road.
/// Design: docs/design/platforms/gtk/controls.md#on-or-off
@MainActor
class GTKToggleView: GTKView {
    /// What the control does when it turns, handed whether it stands on.
    var onToggled: ((Bool) -> Void)?

    /// Makes the control; `property` is the one its turn notifies.
    init(_ make: @escaping () -> GTKWidget?, turning property: String) {
        super.init { _ in make() }
        notify(property) { _, _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKToggleView else { return }
                view.onToggled?(view.isOn)
            }
        }
    }

    /// Whether the control stands on.
    var isOn: Bool { false }

    /// Turns the control on or off.
    func setOn(_ on: Bool) {}

    override func detach() {
        super.detach()
        onToggled = nil
    }
}
