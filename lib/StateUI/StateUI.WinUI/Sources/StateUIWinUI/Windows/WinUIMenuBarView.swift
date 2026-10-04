// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A window's menu bar: WinUI's `MenuBar` beneath the chrome, the visible page's menus on it, an item the user
/// chooses run by its place.
/// Design: docs/design/platforms/winui/pages.md#menus
@MainActor
final class WinUIMenuBarView: WinUIView {
    /// The menus the bar shows, as they were last written.
    private(set) var shown = WinUIMenu()

    /// The bars' colours the bar was last painted in; nil before the first.
    private var painted: (background: HostValue?, foreground: HostValue?)?

    init() {
        super.init { number in stateui_winui_menu_bar_make(number) }
    }

    /// Shows `menu`, the bar written again only where what it draws changed: a menu the user holds open stays.
    func show(_ menu: WinUIMenu) {
        menuActions = menu.actions
        guard !menu.draws(like: shown) else { return }

        shown = menu
        menu.relayed { stateui_winui_menu_bar_set(handle, number, $0, $1, $2, $3, $4, $5, $6) }
    }

    /// Paints the bar as one of the window's bars: in the bars' colour, its menus' words in theirs - the colour
    /// written, else light on a dark bar and dark on a light one (`BandWords`).
    func paint(background: HostValue?, foreground: HostValue?) {
        guard painted.map({ $0 != background || $1 != foreground }) ?? true else { return }

        painted = (background, foreground)
        let fill = background?.argb
        let words = BandWords.color(on: background, written: foreground)?.argb
        let light = background.flatMap(BandWords.light(on:))
        stateui_winui_menu_bar_set_colours(
            handle, fill != nil, fill ?? 0, words != nil, words ?? 0, light.map { $0 ? 1 : 2 } ?? 0)
    }

    override func detach() {
        super.detach()
        shown = WinUIMenu()
        painted = nil
    }
}
