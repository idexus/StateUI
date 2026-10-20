// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Switch and a CheckBox: whether it is on, whether it can be turned, and the turn the user makes; its colour,
    /// and the words it says beside it.
    static func toggles(_ registry: Registry<UIView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = UIKitSwitchView()
            toggle.onToggled = { on in reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled) }
            return toggle
        }, members: { toggle in
            toggle.property(SwitchContract.isOn) { view, on in view.setOn(on ?? false) }
            toggle.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            toggle.property(TintElementContract.tint) { view, tint in
                view.control.onTintColor = tint.flatMap { UIColor(stateUI: $0.propValue) }
            }
            toggle.applies(TextMembers.captionMembers) { view, values in
                view.setCaption(
                    TextMembers.caption(values),
                    color: values[TextColorElementContract.textColor].flatMap { UIColor(stateUI: $0.propValue) })
            }
            toggle.raises(SwitchContract.toggled)
        })
        registry.add(CheckBoxContract.self, create: { reports in
            let box = UIKitCheckView()
            box.onToggled = { on in reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled) }
            return box
        }, members: { box in
            box.property(CheckBoxContract.isOn) { view, on in view.setOn(on ?? false) }
            box.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            box.property(TintElementContract.tint) { view, tint in
                view.tintColor = tint.flatMap { UIColor(stateUI: $0.propValue) }
            }
            box.applies(TextMembers.captionMembers) { view, values in
                view.setText(TextMembers.caption(values))
                view.setLook(TextMembers.captionLook(values))
            }
            box.raises(CheckBoxContract.toggled)
        })
    }
}
#endif
