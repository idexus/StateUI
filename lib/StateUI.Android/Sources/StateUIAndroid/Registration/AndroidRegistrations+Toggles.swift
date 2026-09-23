// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// A Switch: whether it is on, whether it can be turned, and the turn the user makes.
    static func toggles(_ registry: Registry<AndroidView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = AndroidSwitchView()
            toggle.onToggled = { on in reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled) }
            return toggle
        }, members: { toggle in
            toggle.property(SwitchContract.isOn) { view, on in view.setOn(on ?? false) }
            toggle.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            toggle.raises(SwitchContract.toggled)
        })
    }
}
