// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A switch and a check box: one value the user turns on, taken whole with the enabled state and the words
    /// each says beside it, in their case and color.
    static func toggles(_ registry: Registry<NSView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = AppKitSwitchView()
            toggle.onToggled = { on in
                reports.report(ToggleElementContract.isOn, on, as: ToggleElementContract.toggled)
            }
            return toggle
        }, members: { toggle in
            toggle.applies(ToggleElementContract.isOn, EnabledElementContract.isEnabled, TextMembers.captionMembers) {
                view, values in
                view.apply(
                    toggled: values[ToggleElementContract.isOn] ?? false,
                    enabled: values[EnabledElementContract.isEnabled] ?? true,
                    text: TextMembers.caption(values),
                    textColor: values[TextColorElementContract.textColor].flatMap { nsColor($0.propValue) })
            }
            toggle.declares(ToggleElementContract.toggled)
        })

        registry.add(CheckBoxContract.self, create: { reports in
            let box = AppKitCheckBoxView()
            box.onToggled = { on in
                reports.report(ToggleElementContract.isOn, on, as: ToggleElementContract.toggled)
            }
            return box
        }, members: { box in
            box.applies(
                ToggleElementContract.isOn, EnabledElementContract.isEnabled, TintElementContract.tint,
                TextMembers.captionMembers) { view, values in
                view.apply(
                    checked: values[ToggleElementContract.isOn] ?? false,
                    enabled: values[EnabledElementContract.isEnabled] ?? true,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) },
                    text: TextMembers.caption(values),
                    textColor: values[TextColorElementContract.textColor].flatMap { nsColor($0.propValue) })
            }
            box.declares(ToggleElementContract.toggled)
        })
    }
}

#endif
