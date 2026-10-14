// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A Picker: WinUI's `ComboBox`, its choices, the one chosen and its list, which the user opens and closes - or, as
/// its presentation says, a `SelectorBar` of segments or `RadioButtons`, the relay telling each apart.
/// Design: docs/design/platforms/winui/controls.md#a-picker
@MainActor
final class WinUIPickerView: WinUIView {
    override var takesDirection: Bool { true }

    /// What the picker does as the user chooses, opens its list and closes it.
    var onChosen: ((Int) -> Void)?
    var onOpened: (() -> Void)?
    var onClosed: (() -> Void)?

    /// The choices and the choice as the tree last wrote them (`PickerChoices`).
    private var written = PickerChoices()

    /// Whose the list's opening and closing are.
    private var showing = PickerOpening()

    /// The choice shown last, as the program wrote it or the user made it: WinUI's `RadioButtons` applies the
    /// program's a turn after the write, once its buttons stand, and tells it as a change - the program's own.
    /// Design: docs/design/platforms/winui/controls.md#a-pickers-segments-and-radio-buttons
    private var standing: Int?

    init(presentation: PickerPresentation = .menu) {
        super.init { number in stateui_winui_picker_make(number, presentation.rawValue) }
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
        if write.writesChoice { standing = write.chosen ?? -1 }
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

    override func chose(_ index: Int) {
        guard index != standing else { return }
        standing = index
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
