// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Switch, a CheckBox and a RadioButton: whether it is on, whether it can be turned, and the turn the user makes;
    /// a radio button's caption too.
    static func toggles(_ registry: Registry<UIView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = UIKitSwitchView()
            toggle.onToggled = { on in reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled) }
            return toggle
        }, members: { toggle in
            toggle.property(SwitchContract.isOn) { view, on in view.setOn(on ?? false, animated: false) }
            toggle.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            toggle.raises(SwitchContract.toggled)
        })
        registry.add(CheckBoxContract.self, create: { reports in
            let box = UIKitCheckView(radio: false)
            box.onToggled = { on in reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled) }
            return box
        }, members: { box in
            box.property(CheckBoxContract.isOn) { view, on in view.setOn(on ?? false) }
            box.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            box.raises(CheckBoxContract.toggled)
        })
        registry.add(RadioButtonContract.self, create: { reports in
            let radio = UIKitCheckView(radio: true)
            radio.onToggled = { on in reports.report(RadioButtonContract.isOn, on, as: RadioButtonContract.toggled) }
            return radio
        }, members: { radio in
            radio.applies(TextMembers.members) { view, values in
                if let words = TextMembers.words(values) { view.setText(words) }
                if let look = TextMembers.look(values) { view.setLook(look) }
            }
            radio.property(RadioButtonContract.isOn) { view, on in view.setOn(on ?? false) }
            radio.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            radio.raises(RadioButtonContract.toggled)
        })
    }
}
#endif
