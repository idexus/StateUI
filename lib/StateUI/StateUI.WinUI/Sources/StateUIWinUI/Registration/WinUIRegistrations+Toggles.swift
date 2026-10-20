// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A Switch and a CheckBox: whether it is on, whether it can be turned, and the turn the user makes; its colour,
    /// and the words it says and their colour.
    static func toggles(_ registry: Registry<WinUIView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = WinUISwitchView()
            toggle.onToggled = { on in reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled) }
            return toggle
        }, members: { toggle in
            toggle.property(SwitchContract.isOn) { view, on in view.setOn(on ?? false) }
            toggle.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            toggle.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            toggle.applies(TextMembers.captionMembers) { view, values in
                view.setWords(TextMembers.caption(values), color: values[TextColorElementContract.textColor]?.propValue)
            }
            toggle.raises(SwitchContract.toggled)
        })
        registry.add(CheckBoxContract.self, create: { reports in
            let box = WinUICheckBoxView()
            box.onToggled = { on in reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled) }
            return box
        }, members: { box in
            box.property(CheckBoxContract.isOn) { view, on in view.setOn(on ?? false) }
            box.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            box.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            box.applies(TextMembers.captionMembers) { view, values in
                view.setWords(TextMembers.caption(values), color: values[TextColorElementContract.textColor]?.propValue)
            }
            box.raises(CheckBoxContract.toggled)
        })
    }
}
