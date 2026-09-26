// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A WinUI window: its title, its one chrome across the top, its menu bar and the row of tabs beneath it, and the
/// page shown in it, activated the first time it has one.
/// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
@MainActor
final class WinUIWindow {
    /// The window, held until this is released.
    let handle: StateUIObjectRef

    /// The title last given; nil before the first.
    private var title: String??

    /// The view the window shows.
    private(set) var content: WinUIView?

    /// What the window lays over its page and its sheets.
    private(set) var overlay: WinUIView?

    /// The window's chrome, its menu bar, and the row a window's tabs stand in.
    let titleBar = WinUITitleBarView()
    let menuBar = WinUIMenuBarView()
    let tabRow = WinUITabsView()

    /// Whether the menu bar stands beneath the chrome: while the visible page has menus.
    private(set) var menuBarStands = false

    /// Where the row of tabs stands: across the window beneath its chrome, or across a split view's detail.
    private(set) var tabsStandInWindow = false
    private(set) weak var tabsSplit: WinUISplitView?

    private var activated = false

    /// The place and size last asked for - x, y, width, height - each its own request.
    private var frameRequests: [Double?] = [nil, nil, nil, nil]

    /// The bounds last given and whether the window was translucent; nil before the first.
    private var bounds: [Double]?
    private var translucent = false

    /// The number the window's own events name it by: its chrome's.
    var number: Int64 { titleBar.number }

    /// Whether the window was closed: what it tells after that is its closing's, and no one's to hear.
    private(set) var isClosed = false

    init() {
        handle = stateui_winui_window_make(titleBar.number)!
        stateui_winui_window_set_chrome(handle, titleBar.handle, nil, nil)
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

    /// Moves and sizes the window where a request changed, each alone: one kept leaves the window where the user put
    /// it. Places and sizes are DIPs, a place from the corner of the screen's work area, a size the content's.
    /// Design: docs/design/platforms/winui/runtime.md#a-windows-frame
    func request(x: Double?, y: Double?, width: Double?, height: Double?) {
        let requests = [x, y, width, height]
        let changed = zip(requests, frameRequests).map { request, last in request != nil && request != last }
        frameRequests = requests
        guard changed.contains(true) else { return }
        stateui_winui_window_set_frame(handle, changed, requests.map { $0 ?? 0 })
    }

    /// Bounds the content's size - 0 for no bound, the least winning - and lets the user maximize and minimize the
    /// window or not.
    func bound(
        minimumWidth: Double, minimumHeight: Double, maximumWidth: Double, maximumHeight: Double,
        maximizable: Bool, minimizable: Bool
    ) {
        let bounds = [
            minimumWidth, minimumHeight, maximumWidth, maximumHeight, maximizable ? 1 : 0, minimizable ? 1 : 0,
        ]
        guard self.bounds != bounds else { return }
        self.bounds = bounds
        stateui_winui_window_set_limits(handle, bounds, maximizable, minimizable)
    }

    /// Paints the window's backdrop translucent, or of the desktop's tint.
    func setTranslucent(_ translucent: Bool) {
        guard self.translucent != translucent else { return }
        self.translucent = translucent
        stateui_winui_window_set_translucent(handle, translucent)
    }

    /// Shows `view` as the window's content - the first one activates the window.
    func show(_ view: WinUIView?) {
        content = view
        stateui_winui_window_set_content(handle, view?.handle)
        guard view != nil, !activated else { return }

        activated = true
        stateui_winui_window_activate(handle)
    }

    /// Shows `chrome`, its menus beneath it, and `tabs` - across the split view's detail they stand in, or across the
    /// window.
    func apply(_ chrome: WinUIWindowChrome, tabs: WinUIWindowTabs?) {
        setTitle(chrome.title)
        titleBar.apply(chrome)
        menuBar.show(chrome.menuBar)
        if chrome.menuBar.isEmpty == menuBarStands {
            menuBarStands.toggle()
            standChrome()
        }
        if let tabs {
            tabRow.onChosen = tabs.select
            tabRow.show(tabs.titles, chosen: tabs.selected)
        }

        let inWindow = tabs != nil && tabs?.split == nil
        let split = tabs?.split
        guard inWindow != tabsStandInWindow || split !== tabsSplit else { return }

        // Out of where it stood before it stands anywhere else: an element has one parent.
        tabsSplit?.setDetailRow(nil)
        if tabsStandInWindow {
            tabsStandInWindow = false
            standChrome()
        }
        tabsSplit = split
        tabsStandInWindow = inWindow
        split?.setDetailRow(tabRow)
        if inWindow { standChrome() }
    }

    /// Stands the chrome across the window, and beneath it the menu bar and the tabs where they stand there.
    private func standChrome() {
        stateui_winui_window_set_chrome(
            handle, titleBar.handle, menuBarStands ? menuBar.handle : nil, tabsStandInWindow ? tabRow.handle : nil)
    }

    /// Shows `sheets` over everything the window shows, the last on top.
    /// Design: docs/design/platforms/winui/pages.md#the-modal-stack
    func showSheets(_ sheets: [WinUISheetView]) {
        let handles: [StateUIObjectRef?] = sheets.map(\.handle)
        stateui_winui_window_set_sheets(handle, handles, Int32(handles.count))
    }

    /// Lays `view` over the page and its sheets, where the page stands - a click beside what it holds goes on to
    /// them; nil takes it away.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-overlay
    func showOverlay(_ view: WinUIView?) {
        overlay = view
        stateui_winui_window_set_overlay(handle, view?.handle)
    }

    /// Closes the window.
    func close() {
        isClosed = true
        stateui_winui_window_close(handle)
    }
}
