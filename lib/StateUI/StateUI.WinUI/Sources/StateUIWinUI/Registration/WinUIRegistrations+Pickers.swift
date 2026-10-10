// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A Picker: its choices and the one chosen, what it says while none is, its words' look, and its list, which the
    /// user opens, closes and chooses from.
    static func pickers(_ registry: Registry<WinUIView>) {
        registry.add(PickerContract.self, create: { reports in
            let picker = WinUIPickerView()
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
            picker.property(PickerContract.isOpen) { view, open in view.setOpen(open ?? false) }
            picker.applies(TextMembers.lookMembers) { view, values in view.setLook(TextMembers.look(of: values)) }
            picker.property(TextAlignmentElementContract.horizontalTextAlignment) { view, alignment in
                view.setAlignment(alignment ?? .start)
            }
            picker.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(PickerContract.selectedIndexChanged)
            picker.raises(PickerContract.opened)
            picker.raises(PickerContract.closed)
        })
    }
}
