// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Switch and a CheckBox: whether it is on, whether it can be turned, and the turn the user makes; the
    /// words it says beside it, and their colour.
    static func toggles(_ registry: Registry<AndroidView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = AndroidSwitchView()
            toggle.onToggled = { on in reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled) }
            return toggle
        }, members: { toggle in
            toggle.property(SwitchContract.isOn) { view, on in view.setOn(on ?? false) }
            toggle.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            toggle.applies(TextMembers.captionMembers) { view, values in
                view.setText(TextMembers.caption(values))
                view.setLook(TextMembers.captionLook(values))
            }
            toggle.raises(SwitchContract.toggled)
        })
        registry.add(CheckBoxContract.self, create: { reports in
            let box = AndroidCheckBoxView()
            box.onToggled = { on in reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled) }
            return box
        }, members: { box in
            box.property(CheckBoxContract.isOn) { view, on in view.setOn(on ?? false) }
            box.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            box.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            box.applies(TextMembers.captionMembers) { view, values in
                view.setText(TextMembers.caption(values))
                view.setLook(TextMembers.captionLook(values))
            }
            box.raises(CheckBoxContract.toggled)
        })
    }
}
