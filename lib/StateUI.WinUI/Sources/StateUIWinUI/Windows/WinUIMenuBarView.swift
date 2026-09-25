// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A window's menu bar: WinUI's `MenuBar` beneath the chrome, the visible page's menus on it, an item the user
/// chooses run by its place.
/// Design: docs/design/platforms/winui/pages.md#menus
@MainActor
final class WinUIMenuBarView: WinUIView {
    /// The menus the bar shows, as they were last written.
    private(set) var shown = WinUIMenu()

    init() {
        super.init { number in stateui_winui_menu_bar_make(number) }
    }

    /// Shows `menu`, the bar written again only where what it draws changed: a menu the user holds open stays.
    func show(_ menu: WinUIMenu) {
        menuActions = menu.actions
        guard !menu.draws(like: shown) else { return }

        shown = menu
        WinUIStrings.withCStrings(menu.titles) { titles in
            menu.kinds.withUnsafeBufferPointer { kinds in
                menu.enabled.withUnsafeBufferPointer { enabled in
                    stateui_winui_menu_bar_set(
                        handle, number, kinds.baseAddress, titles, enabled.baseAddress, Int32(kinds.count))
                }
            }
        }
    }

    override func detach() {
        super.detach()
        shown = WinUIMenu()
    }
}
