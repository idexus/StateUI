// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A ColorPicker: the color, and what the user chooses; whether the picker offers opacity.
    static func colors(_ registry: Registry<WinUIView>) {
        registry.add(ColorPickerContract.self, create: { reports in
            let picker = WinUIColorPickerView()
            picker.onChosen = { color in
                reports.report(ColorPickerContract.color, color, as: ColorPickerContract.colorChanged)
            }
            return picker
        }, members: { picker in
            picker.applies(ColorPickerContract.color, ColorPickerContract.choosesOpacity) { view, values in
                view.apply(
                    color: values[ColorPickerContract.color] ?? ColorChoice.unset,
                    write: values.changed(ColorPickerContract.color),
                    choosesOpacity: values[ColorPickerContract.choosesOpacity] ?? false)
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(ColorPickerContract.colorChanged)
        })
    }
}
