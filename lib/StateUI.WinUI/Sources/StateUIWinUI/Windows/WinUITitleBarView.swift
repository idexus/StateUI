// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// The one chrome of a StateUI window: WinUI's `TitleBar`. WinUI owns placement, overflow, the caption buttons and
/// dragging the window; StateUI owns what stands on it - its way back and sidebar toggle as the bar's own buttons,
/// an action as a button of its command bar, an authored slot's view attached as it is.
/// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
@MainActor
final class WinUITitleBarView: WinUIView {
    /// The chrome the bar shows, as it was last composed.
    private(set) var chrome = WinUIWindowChrome()

    /// The actions as they were last drawn, the primary ones first.
    private var drawn: [WinUIToolbarAction] = []
    private var drawnOverflow: [Bool] = []

    init() {
        super.init { number in stateui_winui_title_bar_make(number) }
    }

    /// Shows `chrome`, writing only the parts that changed.
    func apply(_ chrome: WinUIWindowChrome) {
        let previous = self.chrome
        self.chrome = chrome

        let background = chrome.background.flatMap(WinUIBrush.argb)
        let foreground = chrome.foreground.flatMap(WinUIBrush.argb)
        stateui_winui_title_bar_set(
            handle, chrome.title, chrome.back != nil, chrome.sidebarToggle != nil,
            background != nil, background ?? 0, foreground != nil, foreground ?? 0)

        let actions = chrome.actions + chrome.overflow
        let overflows = chrome.actions.map { _ in false } + chrome.overflow.map { _ in true }
        if actions.count != drawn.count || overflows != drawnOverflow
            || !zip(actions, drawn).allSatisfy({ $0.draws(like: $1) }) {
            WinUIStrings.withCStrings(actions.map(\.title)) { titles in
                stateui_winui_title_bar_set_actions(
                    handle, titles, overflows, actions.map(\.isEnabled), Int32(actions.count))
            }
            drawnOverflow = overflows
        }
        drawn = actions

        if previous.leading !== chrome.leading || previous.center !== chrome.center
            || previous.trailing !== chrome.trailing {
            stateui_winui_title_bar_set_slots(handle, chrome.leading?.handle, chrome.center?.handle, chrome.trailing?.handle)
        }
    }

    /// The user pressed the way back (-1), the sidebar's toggle (-2), or an action by its place.
    override func chose(_ index: Int) {
        switch index {
        case -1: chrome.back?.perform()
        case -2: chrome.sidebarToggle?()
        default: if drawn.indices.contains(index), drawn[index].isEnabled { drawn[index].perform() }
        }
    }

    override func detach() {
        super.detach()
        chrome = WinUIWindowChrome()
        drawn = []
    }
}
