// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A ColorPicker: the color, and what the user chooses; the browser's input chooses no opacity.
    static func colors(_ registry: Registry<WebDOMView>) {
        registry.add(ColorPickerContract.self, create: { reports in
            let picker = WebColorPickerView()
            picker.onChosen = { color in
                reports.report(ColorPickerContract.color, color, as: ColorPickerContract.colorChanged)
            }
            return picker
        }, members: { picker in
            picker.property(ColorPickerContract.color) { view, color in view.setColor(color ?? ColorChoice.unset) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(ColorPickerContract.colorChanged)
        })
    }
}
