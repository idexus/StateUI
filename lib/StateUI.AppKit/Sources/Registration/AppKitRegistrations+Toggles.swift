// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

extension AppKitRegistrations {
    /// A switch, a check box and a radio button: one value the user turns on,
    /// taken whole with the enabled state - and, for the radio button, the
    /// caption it draws in the font and case the tree describes. Which of the
    /// set's other buttons lose their check is the host's, not the view's: a
    /// set is named across the window, and only the tree knows who is in it.
    static func toggles(_ registry: Registry<NSView>) {
        registry.add(SwitchContract.self, create: { reports in
            let toggle = AppKitSwitchView()
            toggle.onToggled = { on in
                reports.report(SwitchContract.isOn, on, as: SwitchContract.toggled)
            }
            return toggle
        }, members: { toggle in
            toggle.applies([SwitchContract.isOn, VisualElementContract.isEnabled]) { view, values in
                view.apply(
                    toggled: values[SwitchContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
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
            ]) { view, values in
                view.apply(
                    checked: values[CheckBoxContract.isOn] ?? false,
                    enabled: values[VisualElementContract.isEnabled] ?? true,
                    tint: values[TintElementContract.tint].flatMap { nsColor($0.propValue) })
            }
            box.raises(CheckBoxContract.toggled)
        })

        registry.add(RadioButtonContract.self, create: { reports in
            let radio = AppKitRadioButtonView()
            radio.onSelected = {
                reports.report(RadioButtonContract.isOn, true, as: RadioButtonContract.toggled)
            }
            return radio
        }, members: { radio in
            radio.applies([
                RadioButtonContract.isOn, TextElementContract.text, TextElementContract.textCase,
                FontElementContract.fontFamily, FontElementContract.fontSize,
                FontElementContract.fontAttributes, TextStyleElementContract.textColor,
                VisualElementContract.isEnabled,
            ]) { view, values in
                view.apply(
                    checked: values[RadioButtonContract.isOn] ?? false,
                    text: appKitTextCased(
                        values[TextElementContract.text] ?? "",
                        values[TextElementContract.textCase]?.rawValue),
                    font: appKitFont(
                        family: values[FontElementContract.fontFamily]?.text,
                        size: values[FontElementContract.fontSize],
                        attributes: values[FontElementContract.fontAttributes]?.rawValue,
                        fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize)),
                    textColor: values[TextStyleElementContract.textColor]
                        .flatMap { nsColor($0.propValue) } ?? .controlTextColor,
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            radio.raises(RadioButtonContract.toggled)
        })
    }
}

#endif
