// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A Picker: its choices and the one chosen, which the user chooses too, and the look of the chosen one's words.
    static func pickers(_ registry: Registry<GTKView>) {
        // Each presentation is another control: the picker is made as the one it is made with.
        registry.add(PickerContract.self, create: { reports -> GTKView in
            let picker: any GTKChoosing = switch PickerChoices.presentation(made: reports.made) {
            case .menu: GTKPickerView()
            case .segmented: GTKChoiceGroupView(segmented: true)
            case .radio: GTKChoiceGroupView(segmented: false)
            }
            picker.onChosen = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            return picker
        }, members: { (picker: Registration<PickerContract, GTKView>) in
            picker.applies([PickerContract.options, PickerContract.selectedIndex]) { view, values in
                (view as! any GTKChoosing).setChoices(
                    values[PickerContract.options] ?? [], chosen: values[PickerContract.selectedIndex] ?? -1,
                    writeChosen: values.changed(PickerContract.selectedIndex))
            }
            picker.applies(TextMembers.lookMembers) { view, values in
                // A drop-down's words are its button's; a group's buttons take the box's, which GTK's CSS hands on.
                let part = view is GTKPickerView ? " > button" : ""
                (view as! any GTKChoosing).setWordsClass(
                    GTKStyleSheet.words(TextMembers.look(of: values), placeholder: nil, in: part))
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(PickerContract.selectedIndexChanged)
        })
    }
}
