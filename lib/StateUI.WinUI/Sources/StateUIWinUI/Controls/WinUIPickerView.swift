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

    /// The choices the relay holds.
    private var options: [String]?

    /// A change of the list's showing the program asked for, which the user did not make.
    private var programOpens = false
    private var programCloses = false

    init() {
        super.init { number in stateui_winui_picker_make(number) }
    }

    /// The choices, the one chosen - written only where `writeChosen` or the choices changed, so the user's choice
    /// is never argued with - and what the picker says while none is.
    func setChoices(_ choices: [String], chosen: Int, writeChosen: Bool, title: String) {
        let changed = choices != options
        if changed {
            options = choices
            WinUIStrings.withCStrings(choices) { pointers in
                stateui_winui_picker_set_options(handle, pointers, Int32(choices.count))
            }
        }
        stateui_winui_picker_set(handle, Int32(clamping: chosen), writeChosen || changed, title)
    }

    /// Where the choices stand across the picker.
    func setAlignment(_ alignment: TextAlignment) {
        stateui_winui_picker_set_alignment(handle, alignment.rawValue)
    }

    /// Opens or closes the list; neither is the user's, so neither is reported. WinUI may show the list a moment
    /// later, so the program's asking stands until the list says it opened or closed, or the program asks otherwise.
    func setOpen(_ open: Bool) {
        programOpens = open
        programCloses = !open
        guard open != isOpen else {
            programOpens = false
            programCloses = false
            return
        }
        stateui_winui_picker_set_open(handle, open)
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
        if open {
            if programOpens { programOpens = false } else { onOpened?() }
        } else {
            if programCloses { programCloses = false } else { onClosed?() }
        }
    }

    override func detach() {
        super.detach()
        onChosen = nil
        onOpened = nil
        onClosed = nil
    }
}
