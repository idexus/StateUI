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

    init(_ element: MountedElement, runtime: HostRuntime) {
        self.element = element
        self.runtime = runtime
        window.bar.onBack = { [weak self] in self?.goBack(in: runtime) }
        window.bar.onToggle = { [weak self] in self?.toggleSidebar() }
    }

    /// Shows what the element asks for now; a split view shown is given its first room.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.web.view) }
        if let overlays = changes.overlays { window.showOverlays(overlays.compactMap(\.web.view)) }
        if let pages = changes.sheets { showSheets(pages) }
        (presentation.arrangement?.web.view as? WebSplitView)?.adapt()
    }

    /// Keeps a sheet for each page presented, in its order: a sheet gone closes, the last first, and one new is shown
    /// over those before it.
    /// Design: docs/design/platforms/web/pages.md#sheets
    private func showSheets(_ pages: [MountedElement]) {
        let kept = sheets.filter { entry in
            pages.contains { $0 === entry.element && $0.web.view === entry.sheet.page }
        }
        for entry in sheets.reversed() where !kept.contains(where: { $0.sheet === entry.sheet }) { entry.sheet.close() }
        sheets = pages.compactMap { page in
            if let entry = kept.first(where: { $0.element === page }) { return entry }
            guard let view = page.web.view else { return nil }
            let sheet = WebSheet(page: view)
            sheet.onClosedByUser = { [weak self] in self?.dismissTopSheet() }
            sheet.bar.onBack = { [weak self] in
                guard let self else { return }
                goBack(in: runtime)
            }
            sheet.present()
            return (page, sheet)
        }
    }

    /// The user took the top sheet away: the modal stack is told how many remain.
    private func dismissTopSheet() {
        guard let element, !presentation.sheets.isEmpty else { return }
        runtime.goBack(.dismissSheet(remaining: presentation.sheets.count - 1), in: element)
    }

    /// Writes the window's chrome on its bar and each sheet's on the sheet's, and names the tab after the page the
    /// user sees.
    /// Design: docs/design/platforms/web/pages.md#the-windows-bar
    func refreshChrome() {
        guard let element else { return }
        let chrome = WindowChrome(window: element, arrangement: presentation.arrangement)
        var title = chrome.title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string ?? ""
        let split = chrome.sidebarToggle?.web.view as? WebSplitView
        window.bar.show(chrome, title: title, sidebar: split?.isPresented)
        for (page, sheet) in sheets {
            let own = WindowChrome(window: element, arrangement: page)
            let named = own.title.flatMap { $0.isEmpty ? nil : $0 } ?? ""
            sheet.bar.show(own, title: named, sidebar: nil)
            if !named.isEmpty { title = named }
        }
        WebRelay.setTitle(title)
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
