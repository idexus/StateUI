// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One window element shown in a WinUI window: its arrangement of pages, its sheets, its overlay and its chrome,
/// kept in step with the element as the tree changes, and the element told once that its window was made.
/// Design: docs/design/platforms/winui/runtime.md#the-window
@MainActor
final class WinUIWindowController {
    /// The window element shown.
    private(set) weak var element: MountedElement?

    /// The WinUI window it is shown in.
    let window = WinUIWindow()

    /// What the window shows, by the host layer's rule: its arrangement of pages, its overlay, and that it was made.
    private let presentation = WindowPresentation()

    /// The sheets the window shows, one for each page its modal stack presents, the last on top.
    private var sheets: [(element: MountedElement, sheet: WinUISheetView)] = []

    init(_ element: MountedElement) {
        self.element = element
    }

    /// Shows what the element asks for now; a window shown the first time is told it was made before it is shown,
    /// and so before it hears it came to the front.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        applyFrame(of: element)
        // What the user sees is the top sheet, else the window's arrangement: the one that stops showing hears it,
        // then the one that starts - by the window's own coming and going, or by a sheet's, as a move.
        let previousVisible = sheets.last?.element ?? presentation.arrangement
        let hadSheets = !sheets.isEmpty
        let changes = presentation.show(element)
        if let created = changes.created { runtime.pump.handlers.enqueuePhase(created) }
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.winUI.view) }
        showSheets(of: element)
        if let overlay = changes.overlay { window.showOverlay(overlay?.winUI.view) }
        let visible = sheets.last?.element ?? presentation.arrangement
        if visible !== previousVisible {
            let reason: WinUIPagePresentationReason = hadSheets || !sheets.isEmpty ? .navigation : .window
            previousVisible?.winUI.setPagePresented(false, reason: reason)
            visible?.winUI.setPagePresented(true, reason: reason)
        }
    }

    /// Stands the window as the element asks: its place and size, their bounds, its buttons and its backdrop.
    /// Design: docs/design/platforms/winui/runtime.md#a-windows-frame
    private func applyFrame(of element: MountedElement) {
        let number = { (property: Prop) in element.value(property)?.number }
        window.request(x: number(.x), y: number(.y), width: number(.width), height: number(.height))
        window.bound(
            minimumWidth: number(.minimumWidth) ?? 0, minimumHeight: number(.minimumHeight) ?? 0,
            maximumWidth: number(.maximumWidth) ?? 0, maximumHeight: number(.maximumHeight) ?? 0,
            maximizable: element.value(.isMaximizable)?.bool ?? true,
            minimizable: element.value(.isMinimizable)?.bool ?? true)
        window.setTranslucent(element.value(.isTranslucent)?.bool == true)
    }

    /// Keeps a sheet for each page the window's modal stack presents, in its order, each under its page's title.
    /// Design: docs/design/platforms/winui/pages.md#the-modal-stack
    private func showSheets(of element: MountedElement) {
        let pages = element.children.first { $0.type == .modalStack }?.children
            .filter { NodeType.pageTypes.contains($0.type) } ?? []
        guard !pages.isEmpty || !sheets.isEmpty else { return }

        sheets = pages.map { page in
            let sheet = sheets.first { $0.element === page }?.sheet ?? WinUISheetView()
            sheet.show(title: page.winUI.visiblePage?.value(.title)?.string ?? "", page: page.winUI.view)
            return (page, sheet)
        }
        window.showSheets(sheets.map(\.sheet))
    }

    /// The user took the top sheet away - Escape, the way back of a sheet with none of its own: the window is told
    /// how many remain.
    func dismissTopSheet(in runtime: HostRuntime) {
        guard !sheets.isEmpty, let element, let handler = element.handler(.modalPopped) else { return }
        runtime.dispatch(handler, payload: [.number(Double(sheets.count - 1))])
    }

    /// Composes the window's one chrome again from what it shows now: the top page names the window, the stack's
    /// way back and the page's actions stand on the chrome, a split view adds the sidebar's toggle, the page's menus
    /// and the tabs of a tabbed view on the page path stand beneath it, and an authored title bar adds its slots.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    func refreshChrome(in runtime: HostRuntime) {
        guard let element = element?.winUI else { return }

        let arrangement = presentation.arrangement?.winUI
        arrangement?.markTabsShownByWindow()
        let titleBar = element.children.first { $0.type == .titleBar }
        let actions = arrangement?.visibleToolbarActions ?? (primary: [], overflow: [])

        var chrome = WinUIWindowChrome()
        chrome.title = arrangement?.visiblePage?.value(.title)?.string ?? element.value(.title)?.string ?? ""
        chrome.back = arrangement?.visibleBackAction
        chrome.sidebarToggle = arrangement?.visibleSidebarToggle
        chrome.leading = titleBar?.firstView(in: .leadingContent)
        chrome.center = titleBar?.firstView(in: .content) ?? arrangement?.visibleTitleView
        chrome.trailing = titleBar?.firstView(in: .trailingContent)
        chrome.actions = actions.primary
        chrome.overflow = actions.overflow
        chrome.background = arrangement?.visibleBarBackground ?? titleBar?.value(.background)
        chrome.foreground = arrangement?.visibleBarForeground ?? titleBar?.value(.barForegroundColor)
        chrome.menuBar = WinUIMenu(bar: arrangement?.visiblePage?.children.first { $0.type == .menuBar })
        if let top = sheets.last?.element.winUI {
            chrome.sheet = (
                back: { [weak self, weak top] in
                    if let wayBack = top?.wayBack { wayBack() } else { self?.dismissTopSheet(in: runtime) }
                },
                dismiss: { [weak self] in self?.dismissTopSheet(in: runtime) })
        }
        window.apply(chrome, tabs: arrangement?.visibleWindowTabs)
    }

    /// Goes the way back the arrangement the window shows offers - a stack's top page going; whether there was one.
    /// Design: docs/design/platforms/winui/pages.md#the-way-back
    func goBack() -> Bool {
        guard let wayBack = presentation.arrangement?.winUI.wayBack else { return false }

        wayBack()
        return true
    }

    /// The page's corner in the window, in DIPs: where content stands clear of the window's chrome.
    var safeAreaOrigin: Point {
        window.content?.origin ?? Point(x: 0, y: 0)
    }
}
