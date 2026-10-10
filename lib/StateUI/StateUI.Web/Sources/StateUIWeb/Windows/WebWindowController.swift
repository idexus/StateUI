// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One window element shown in the browser's window: what the host layer says it shows, and the one chrome it
/// composes - its bar, and the title the browser shows on its tab - in step with the element as the tree changes.
/// Design: docs/design/platforms/web/runtime.md#the-window
@MainActor
final class WebWindowController {
    /// The window element shown.
    private(set) weak var element: MountedElement?

    let window = WebWindow()

    /// What the window shows, by the host layer's rule.
    let presentation = WindowPresentation()

    /// A sheet for each page the window's modal stack presents, the last on top.
    private var sheets: [(element: MountedElement, sheet: WebSheet)] = []

    private unowned let runtime: HostRuntime

    /// Whether the page's own entry stands on the browser's history - while the window offers a way back - and
    /// whether the browser's history moving next is the page's own going back over it.
    private var holdsHistory = false
    private var leavesHistory = false

    /// What the window hears the browser's history move by, until it closes.
    private var historyListener: Int32 = 0

    init(_ element: MountedElement, runtime: HostRuntime) {
        self.element = element
        self.runtime = runtime
        window.bar.onBack = { [weak self] in self?.goBack(in: runtime) }
        window.bar.onToggle = { [weak self] in self?.toggleSidebar() }
        historyListener = WebRelay.listener { [weak self] in self?.historyMoved() }
        WebRelay.listenToHistory(historyListener)
    }

    /// Keeps the page's own entry on the browser's history while the window offers a way back, and none while not.
    /// Design: docs/design/platforms/web/pages.md#the-browsers-way-back
    private func followHistory() {
        let offers = presentation.wayBack != nil
        if offers, !holdsHistory {
            holdsHistory = true
            WebRelay.pushHistory()
        } else if !offers, holdsHistory {
            holdsHistory = false
            leavesHistory = WebRelay.backHistory()
        }
    }

    /// The browser's history moved: its way back took the page's entry, and the window goes back a step - or the
    /// page's own going back over it, or the browser's way forward onto it, which the window follows as it can.
    private func historyMoved() {
        if leavesHistory {
            leavesHistory = false
            return
        }
        if holdsHistory {
            holdsHistory = false
            goBack(in: runtime)
        } else {
            holdsHistory = true
            followHistory()
        }
    }

    /// Shows what the element asks for now; a split view shown is given its first room.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let traits = changes.traits { window.frame.setBackground(traits.background.painted) }
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.web.view) }
        if let overlays = changes.overlays { window.showOverlays(overlays.compactMap(\.web.view)) }
        if let pages = changes.sheets { showSheets(pages) }
        (presentation.arrangement?.web.view as? WebSplitView)?.adapt()
    }

    /// Keeps a sheet for each page presented, in its order, by the host layer's rule (`SheetChange`): a sheet gone
    /// closes, the top first, and one new is shown over those before it.
    /// Design: docs/design/platforms/web/pages.md#sheets
    private func showSheets(_ pages: [MountedElement]) {
        let change = SheetChange(from: sheets, to: pages) { $0.element === $1 && $1.web.view === $0.sheet.page }
        for entry in change.leaving { entry.sheet.close() }
        sheets.removeLast(sheets.count - change.kept)
        for page in change.coming {
            guard let view = page.web.view else { continue }
            let sheet = WebSheet(page: view)
            sheet.onClosedByUser = { [weak self] in self?.dismissTopSheet() }
            sheet.bar.onBack = { [weak self] in
                guard let self else { return }
                goBack(in: runtime)
            }
            sheet.present()
            sheets.append((page, sheet))
        }
    }

    /// Closes the window, the sheets over it first, the top one first: a sheet is a modal dialog of the page's, which
    /// would hold every page after it still.
    func close() {
        for entry in sheets.reversed() { entry.sheet.close() }
        sheets = []
        window.close()
        WebRelay.stopListeningToHistory(historyListener)
    }

    /// The user took the top sheet away: the modal stack is told how many remain.
    private func dismissTopSheet() {
        guard let element, !presentation.sheets.isEmpty else { return }
        runtime.goBack(.dismissSheet(remaining: presentation.sheets.count - 1), in: element)
    }

    /// Writes the window's chrome on its bar and each sheet's on the sheet's, and names the tab after the page the
    /// user sees and the site.
    /// Design: docs/design/platforms/web/pages.md#the-windows-bar
    func refreshChrome() {
        guard let element else { return }
        let chrome = WindowChrome(window: element, arrangement: presentation.arrangement)
        var title = chrome.title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string ?? ""
        let split = chrome.sidebarToggle?.web.view as? WebSplitView
        window.bar.show(chrome, title: title, sidebar: split?.isPresented, split: split)
        // The page the user sees may stand with no bar over it.
        window.bar.setShown(presentation.arrangement?.visiblePage?.value(.showsNavigationBar)?.bool != false)
        for (page, sheet) in sheets {
            let own = WindowChrome(window: element, arrangement: page)
            let named = own.title.flatMap { $0.isEmpty ? nil : $0 } ?? ""
            sheet.bar.show(own, title: named, sidebar: nil)
            if !named.isEmpty { title = named }
        }
        WebRelay.setTitle(Self.tab(page: title, site: WebRelay.siteName))
        followHistory()
    }

    /// What the tab says: the page's title beside the site's name, either alone where the other is none or the
    /// same.
    /// Design: docs/design/platforms/web/pages.md#the-tab
    static func tab(page: String, site: String) -> String {
        if site.isEmpty { return page }
        if page.isEmpty || page == site { return site }
        return "\(page) - \(site)"
    }

    /// Goes the way back the window offers: a stack's top page, or the top sheet.
    /// Design: docs/design/host/pages.md#the-way-back
    func goBack(in runtime: HostRuntime) {
        guard let element, let way = presentation.wayBack else { return }
        runtime.goBack(way, in: element)
    }

    /// Shows or hides the sidebar of the split view the window shows, as the user does.
    private func toggleSidebar() {
        guard let split = WindowChrome(window: element!, arrangement: presentation.arrangement).sidebarToggle,
              let view = split.web.view as? WebSplitView
        else { return }
        view.userPresents(!view.isPresented)
        refreshChrome()
    }
}
