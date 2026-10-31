// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// A control that stands on or off - a switch, a check box - and the turn the user makes, told through one road.
/// Design: docs/design/platforms/gtk/controls.md#on-or-off
@MainActor
class GTKToggleView: GTKView {
    /// What the control does when it turns, handed whether it stands on.
    var onToggled: ((Bool) -> Void)?

    /// The widget that turns: the view's own, or the switch in a switch's row.
    let control: GTKWidget

    /// Makes the view of `widget`, whose `control` notifies `property` as it turns.
    init(_ widget: GTKWidget, control: GTKWidget, turning property: String) {
        self.control = control
        super.init { _ in widget }
        connectNotify(UnsafeMutableRawPointer(control), property, number: number) { _, _, data in
            MainActor.assumeIsolated {
                guard let view = GTKView.find(viewNumber(data)) as? GTKToggleView else { return }
                view.onToggled?(view.isOn)
            }
        }
    }

    override var presentedControl: GTKWidget { control }

    /// Whether the control stands on.
    var isOn: Bool { false }

    /// Turns the control on or off.
    func setOn(_ on: Bool) {}

    override func detach() {
        super.detach()
        onToggled = nil
    }
}
