// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A switch and a check box: one value the user turns on, taken whole with the enabled state and the words
    /// each says beside it, in their case and colour.
    static func toggles(_ registry: Registry<NSView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = AppKitSwitchView()
            toggle.onToggled = { on in
                reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled)
            }
            return toggle
        }, members: { toggle in
            toggle.applies([SwitchContract.isOn, VisualElementContract.isEnabled] + TextMembers.captionMembers) {
                view, values in
                view.apply(
                    toggled: values[SwitchContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    text: TextMembers.caption(values),
                    textColor: values[TextColorElementContract.textColor].flatMap { nsColor($0.propValue) })
            }
            toggle.raises(SwitchContract.toggled)
        })

        registry.add(CheckBoxContract.self, create: { reports in
            let box = AppKitCheckBoxView()
            box.onToggled = { on in
                reports.report(CheckBoxContract.isOn, on, as: CheckBoxContract.toggled)
            }
            return box
        }, members: { box in
            box.applies([
                CheckBoxContract.isOn, VisualElementContract.isEnabled, TintElementContract.tint,
            ] + TextMembers.captionMembers) { view, values in
                view.apply(
                    checked: values[CheckBoxContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    text: TextMembers.caption(values),
                    textColor: values[TextColorElementContract.textColor].flatMap { nsColor($0.propValue) })
            }
            box.raises(CheckBoxContract.toggled)
        })
    }
}

#endif
