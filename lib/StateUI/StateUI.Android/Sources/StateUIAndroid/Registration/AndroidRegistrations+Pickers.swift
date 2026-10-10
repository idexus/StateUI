// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Picker: its options, the choice and the title shown without one, its list opened and closed, and
    /// the words' look.
    static func pickers(_ registry: Registry<AndroidView>) {
        registry.add(PickerContract.self, create: { reports in
            let picker = AndroidPickerView()
            picker.onChosen = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            picker.onOpened = { reports.raise(PickerContract.opened) }
            picker.onClosed = { reports.raise(PickerContract.closed) }
            return picker
        }, members: { picker in
            picker.applies([PickerContract.options, PickerContract.selectedIndex, PickerContract.placeholder]) {
                view, values in
                view.setChoices(
                    values[PickerContract.options] ?? [], chosen: values[PickerContract.selectedIndex] ?? -1,
                    writeChosen: values.changed(PickerContract.selectedIndex), title: values[PickerContract.placeholder] ?? "")
            }
            picker.property(PickerContract.isOpen) { view, open in
                if open == true { view.openList() }
            }
            picker.applies(TextMembers.lookMembers + [TextAlignmentElementContract.horizontalTextAlignment]) { view, values in
                view.setLook(
                    TextMembers.look(of: values),
                    alignment: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
            }
            picker.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(PickerContract.selectedIndexChanged)
            picker.raises(PickerContract.opened)
            picker.raises(PickerContract.closed)
        })
    }
}
