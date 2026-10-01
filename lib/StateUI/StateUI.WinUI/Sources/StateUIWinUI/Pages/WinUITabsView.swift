// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A row of tabs: WinUI's `SelectorBar`, a tab the user chooses handed on by its place.
@MainActor
final class WinUITabsView: WinUIView {
    /// What the row does when the user chooses a tab.
    var onChosen: ((Int) -> Void)?

    /// The tabs shown, and the one chosen among them.
    private(set) var tabs: [WinUITab] = []
    private(set) var chosen = -1

    init() {
        super.init { number in stateui_winui_tabs_make(number) }
    }

    /// Shows the tabs, `chosen` selected, as the program's write; written only where they differ.
    func show(_ tabs: [WinUITab], chosen: Int) {
        guard tabs != self.tabs || chosen != self.chosen else { return }

        self.tabs = tabs
        self.chosen = chosen
        ProgramWrite.perform {
            WinUIStrings.withCStrings(tabs.map(\.title)) { titles in
                WinUIStrings.withCStrings(tabs.map { WinUIStrings.lines($0.icon) }) { icons in
                    stateui_winui_tabs_set(handle, titles, icons, Int32(tabs.count), Int32(chosen))
                }
            }
        }
    }

    override func chose(_ index: Int) {
        guard !ProgramWrite.isWriting else { return }
        chosen = index
        onChosen?(index)
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
