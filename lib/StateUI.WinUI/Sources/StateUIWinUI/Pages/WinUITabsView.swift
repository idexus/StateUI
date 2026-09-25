// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A row of tabs: WinUI's `SelectorBar`, a tab the user chooses handed on by its place.
@MainActor
final class WinUITabsView: WinUIView {
    /// What the row does when the user chooses a tab.
    var onChosen: ((Int) -> Void)?

    /// The titles shown, and the tab chosen among them.
    private(set) var titles: [String] = []
    private(set) var chosen = -1

    init() {
        super.init { number in stateui_winui_tabs_make(number) }
    }

    /// Shows the tabs' titles, `chosen` selected, as the program's write; written only where they differ.
    func show(_ titles: [String], chosen: Int) {
        guard titles != self.titles || chosen != self.chosen else { return }

        self.titles = titles
        self.chosen = chosen
        ProgramWrite.perform {
            WinUIStrings.withCStrings(titles) { pointers in
                stateui_winui_tabs_set(handle, pointers, Int32(titles.count), Int32(chosen))
            }
        }
    }

    override func chose(_ index: Int) {
        guard !ProgramWrite.isWriting else { return }
        chosen = index
        onChosen?(index)
    }

    override func detach() {
        onChosen = nil
    }
}
