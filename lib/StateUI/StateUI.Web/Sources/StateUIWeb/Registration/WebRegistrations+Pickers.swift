// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A Picker: its choices, the one chosen, their words' look, and the choice the user makes.
    static func pickers(_ registry: Registry<WebDOMView>) {
        // Each presentation is another control: the picker is made as the one it is made with.
        registry.add(PickerContract.self, create: { reports -> WebDOMView in
            let picker: any WebChoosing = switch PickerChoices.presentation(made: reports.made) {
            case .menu: WebPickerView()
            case .segmented: WebChoiceGroupView(segmented: true)
            case .radio: WebChoiceGroupView(segmented: false)
            }
            picker.onChosen = { index in
                reports.report(PickerContract.selectedIndex, index, as: PickerContract.selectedIndexChanged)
            }
            return picker
        }, members: { (picker: Registration<PickerContract, WebDOMView>) in
            picker.applies(
                PickerContract.options, PickerContract.selectedIndex, PickerContract.placeholder) { view, values in
                (view as! any WebChoosing).setChoices(
                    values[PickerContract.options] ?? [], chosen: values[PickerContract.selectedIndex] ?? -1,
                    writeChosen: values.changed(PickerContract.selectedIndex), title: values[PickerContract.placeholder])
            }
            picker.applies(TextMembers.lookMembers) { view, values in
                (view as! any WebChoosing).setLook(TextMembers.look(of: values))
            }
            picker.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            picker.raises(PickerContract.selectedIndexChanged)
        })
    }
}
