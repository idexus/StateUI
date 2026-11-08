// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Picker: its options, the choice and the title shown without one, its list opened and closed, and
    /// the words' look.
    static func pickers(_ registry: Registry<AndroidView>) {
        // Each presentation is another control: the picker is made as the one it is made with.
        registry.add(PickerContract.self, create: { reports in
            let picker = AndroidPickerView(presentation: PickerChoices.presentation(made: reports.made))
            picker.onChosen = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            picker.onOpened = { reports.raise(PopupElementContract.opened) }
            picker.onClosed = { reports.raise(PopupElementContract.closed) }
            return picker
        }, members: { picker in
            picker.applies(PickerContract.options, PickerContract.selectedIndex, PlaceholderElementContract.placeholder) {
                view, values in
                view.setChoices(
                    values[PickerContract.options] ?? [], chosen: values[PickerContract.selectedIndex] ?? -1,
                    writeChosen: values.changed(PickerContract.selectedIndex), title: values[PlaceholderElementContract.placeholder] ?? "")
            }
            picker.property(PopupElementContract.isOpen) { view, open in
                if open == true { view.openList() }
            }
            picker.applies(
                TextMembers.lookMembers, TextAlignmentElementContract.horizontalTextAlignment) { view, values in
                view.setLook(
                    TextMembers.look(of: values),
                    alignment: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start)
            }
            picker.property(TintElementContract.tint) { view, tint in view.setTint(tint?.propValue) }
            picker.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.declares(PickerContract.selectedIndexChanged)
            picker.declares(PopupElementContract.opened)
            picker.declares(PopupElementContract.closed)
        })
    }
}
