// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A WinUI window: its title, its one chrome across the top, the row of tabs beneath it, and the page shown in it,
/// activated the first time it has one.
/// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
@MainActor
final class WinUIWindow {
    /// The window, held until this is released.
    let handle: StateUIObjectRef

    /// The title last given; nil before the first.
    private var title: String??

    /// The view the window shows.
    private(set) var content: WinUIView?

    /// The window's chrome, and the row a window's tabs stand in.
    let titleBar = WinUITitleBarView()
    let tabRow = WinUITabsView()

    /// Where the row of tabs stands: across the window beneath its chrome, or across a split view's detail.
    private(set) var tabsStandInWindow = false
    private(set) weak var tabsSplit: WinUISplitView?

    private var activated = false

    init() {
        handle = stateui_winui_window_make()!
        stateui_winui_window_set_chrome(handle, titleBar.handle, nil)
    }

    isolated deinit {
        stateui_winui_release(handle)
    }

    /// The window's name, which the system shows for it; nil for none.
    func setTitle(_ title: String?) {
        guard self.title != .some(title) else { return }
        self.title = .some(title)
        stateui_winui_window_set_title(handle, title ?? "")
    }

    /// Shows `view` as the window's content - the first one activates the window.
    func show(_ view: WinUIView?) {
        content = view
        stateui_winui_window_set_content(handle, view?.handle)
        guard view != nil, !activated else { return }

        activated = true
        stateui_winui_window_activate(handle)
    }

    /// Shows `chrome`, and `tabs` beneath it - across the split view's detail they stand in, or across the window.
    func apply(_ chrome: WinUIWindowChrome, tabs: WinUIWindowTabs?) {
        setTitle(chrome.title)
        titleBar.apply(chrome)
        if let tabs {
            tabRow.onChosen = tabs.select
            tabRow.show(tabs.titles, chosen: tabs.selected)
        }

        let inWindow = tabs != nil && tabs?.split == nil
        let split = tabs?.split
        guard inWindow != tabsStandInWindow || split !== tabsSplit else { return }

        // Out of where it stood before it stands anywhere else: an element has one parent.
        tabsSplit?.setDetailRow(nil)
        if tabsStandInWindow { stateui_winui_window_set_chrome(handle, titleBar.handle, nil) }
        tabsSplit = split
        tabsStandInWindow = inWindow
        split?.setDetailRow(tabRow)
        if inWindow { stateui_winui_window_set_chrome(handle, titleBar.handle, tabRow.handle) }
    }

    /// Closes the window.
    func close() {
        stateui_winui_window_close(handle)
    }
}
