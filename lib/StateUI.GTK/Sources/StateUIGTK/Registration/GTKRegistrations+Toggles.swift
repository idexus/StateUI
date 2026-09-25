// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension GTKRegistrations {
    /// A Switch, a CheckBox and a RadioButton: whether it is on, whether it can be turned, and the turn the user makes;
    /// a radio button's caption too.
    static func toggles(_ registry: Registry<GTKView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = GTKSwitchView()
            toggle.onToggled = { on in reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled) }
            return toggle
        }, members: { toggle in
            toggle.property(SwitchContract.isOn) { view, on in view.setOn(on ?? false) }
            toggle.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            toggle.raises(SwitchContract.toggled)
        })
        registry.add(CheckBoxContract.self, create: { reports in
            let box = GTKCheckView(radio: false)
            box.onToggled = { on in reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled) }
            return box
        }, members: { box in
            box.property(CheckBoxContract.isOn) { view, on in view.setOn(on ?? false) }
            box.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            box.raises(CheckBoxContract.toggled)
        })
        registry.add(RadioButtonContract.self, create: { reports in
            let radio = GTKCheckView(radio: true)
            radio.onToggled = { on in reports.report(RadioButtonContract.isOn, on, as: RadioButtonContract.toggled) }
            return radio
        }, members: { radio in
            radio.applies(textMembers) { view, values in applyText(view, values) }
            radio.property(RadioButtonContract.isOn) { view, on in view.setOn(on ?? false) }
            radio.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            radio.raises(RadioButtonContract.toggled)
        })
    }
}
