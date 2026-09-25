// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A Picker: WinUI's `ComboBox`, its choices, the one chosen and its list, which the user opens and closes.
/// Design: docs/design/platforms/winui/controls.md#a-picker
@MainActor
final class WinUIPickerView: WinUIView {
    /// What the picker does as the user chooses, opens its list and closes it.
    var onChosen: ((Int) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    /// Whose the list's opening and closing are.
    private var showing = WinUIShowing()

    init() {
        super.init { number in stateui_winui_picker_make(number) }
    }

    /// The choices, the one chosen - written only where `writeChosen` or the choices changed, so the user's choice
    /// is never argued with - and what the picker says while none is.
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title: String) {
        let write = written.write(choices, chosen: chosen, choiceChanged: writeChosen)
        if let choices = write.choices {
            WinUIStrings.withCStrings(choices) { pointers in
                stateui_winui_picker_set_options(handle, pointers, Int32(choices.count))
            }
        }
        stateui_winui_picker_set(handle, Int32(clamping: write.chosen ?? -1), write.writesChoice, title)
    }

    /// Where the choices stand across the picker.
    func setAlignment(_ alignment: TextAlignment) {
        stateui_winui_picker_set_alignment(handle, alignment.rawValue)
    }

    /// Opens or closes the list; neither is the user's, so neither is reported.
    func setOpen(_ open: Bool) {
        if showing.programAsks(open: open, shown: isOpen) { stateui_winui_picker_set_open(handle, open) }
    }

    /// Whether the list shows.
    var isOpen: Bool { stateui_winui_picker_is_open(handle) }

    /// The choice WinUI shows; -1 for none.
    var chosen: Int { Int(stateui_winui_picker_selected(handle)) }

    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(handle, enabled)
    }

    override func chose(_ index: Int) {
        onChosen?(index)
    }

    /// The list opened or closed: the user's, reported; the program's, not.
    override func presented(_ open: Bool) {
        guard showing.heard(open: open) else { return }
        if open { onOpened?() } else { onClosed?() }
    }

    override func detach() {
        super.detach()
        onChosen = nil
        onOpened = nil
        onClosed = nil
    }
}
