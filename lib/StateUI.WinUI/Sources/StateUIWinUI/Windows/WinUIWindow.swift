// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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

    /// Whether the window's scene hides it: while another scene is in front.
    private(set) var isHidden = false

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

    /// Moves and sizes the window as `frame` asks, each request alone: a place from the corner of the screen's work
    /// area, a size the content's, in DIPs.
    /// Design: docs/design/platforms/winui/runtime.md#a-windows-frame
    func request(_ frame: WindowFrame) {
        let requests = [frame.x, frame.y, frame.width, frame.height]
        stateui_winui_window_set_frame(handle, requests.map { $0 != nil }, requests.map { $0 ?? 0 })
    }

    /// Bounds the content's size as `bounds` says; one it leaves unsaid is WinUI's own.
    func bound(_ bounds: WindowBounds) {
        let limits = [bounds.minimumWidth, bounds.minimumHeight, bounds.maximumWidth, bounds.maximumHeight]
        stateui_winui_window_set_limits(handle, limits.map { $0 ?? 0 })
    }

    /// Makes the window what `traits` says: a button it leaves unsaid is WinUI's own, which lets the user press it.
    func apply(_ traits: WindowTraits) {
        stateui_winui_window_set_traits(
            handle, traits.isMaximizable ?? true, traits.isMinimizable ?? true, traits.isTranslucent,
            traits.floatsOnTop)
    }

    /// Shows `view` as the window's content - the first one activates the window, unless its scene hides it.
    func show(_ view: WinUIView?) {
        content = view
        stateui_winui_window_set_content(handle, view?.handle)
        activateFirstTime()
    }

    /// Hides the window as its scene goes behind another, or shows it again without activating it; one never shown
    /// is activated as it is first shown.
    func setHidden(_ hidden: Bool) {
        guard hidden != isHidden else { return }
        isHidden = hidden
        if activated {
            stateui_winui_window_set_shown(handle, !hidden)
        } else {
            activateFirstTime()
        }
    }

    /// Activates the window the first time it has content and stands shown.
    private func activateFirstTime() {
        guard content != nil, !activated, !isHidden else { return }

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

    /// Closes the window; one closed already stays as it is.
    func close() {
        guard !isClosed else { return }
        isClosed = true
        stateui_winui_window_close(handle)
    }

    /// The window closed of WinUI's accord - the user closed it: what it tells after that is no one's to hear.
    func closed() {
        isClosed = true
    }
}
