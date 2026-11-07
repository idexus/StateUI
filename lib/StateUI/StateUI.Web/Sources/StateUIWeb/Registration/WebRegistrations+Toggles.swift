// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A Switch and a CheckBox: whether it is on, whether it can be turned, its color, and the turn the user makes;
    /// the words it says beside it and their color.
    static func toggles(_ registry: Registry<WebDOMView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = WebSwitchView(switch: true)
            toggle.onToggled = { on in reports.report(ToggleElementContract.isOn, on, as: ToggleElementContract.toggled) }
            return toggle
        }, members: { toggle in
            toggle.property(ToggleElementContract.isOn) { view, on in view.setOn(on ?? false) }
            toggle.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            toggle.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            toggle.applies(TextMembers.captionMembers) { view, values in
                view.setWords(TextMembers.caption(values), color: values[TextColorElementContract.textColor]?.propValue)
            }
            toggle.declares(ToggleElementContract.toggled)
        })
        registry.add(CheckBoxContract.self, create: { reports in
            let box = WebSwitchView(switch: false)
            box.onToggled = { on in reports.report(ToggleElementContract.isOn, on, as: ToggleElementContract.toggled) }
            return box
        }, members: { box in
            box.property(ToggleElementContract.isOn) { view, on in view.setOn(on ?? false) }
            box.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            box.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            box.applies(TextMembers.captionMembers) { view, values in
                view.setWords(TextMembers.caption(values), color: values[TextColorElementContract.textColor]?.propValue)
            }
            box.declares(ToggleElementContract.toggled)
        })
    }
}
