// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A Picker: its choices and the one chosen, which the user chooses too, and the look of the chosen one's words.
    static func pickers(_ registry: Registry<GTKView>) {
        registry.add(PickerContract.self, create: { reports in
            let picker = GTKPickerView()
            picker.onChosen = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            return picker
        }, members: { picker in
            picker.applies([PickerContract.options, PickerContract.selectedIndex]) { view, values in
                view.setChoices(
                    values[PickerContract.options] ?? [], chosen: values[PickerContract.selectedIndex] ?? -1,
                    writeChosen: values.changed(PickerContract.selectedIndex))
            }
            picker.applies([
                FontElementContract.fontSize, FontElementContract.fontAttributes, FontElementContract.fontFamily,
                TextStyleElementContract.textColor,
            ]) { view, values in
                view.setWordsClass(GTKStyleSheet.words(TextMembers.look(of: values), placeholder: nil, in: " > button"))
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(PickerContract.selectedIndexChanged)
        })
    }
}
