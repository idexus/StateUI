// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// One window element shown in a GTK window: what the host layer says it shows - its arrangement of pages, its
/// overlays, its size, its bounds, whether its scene hides it and the window it belongs to - and the chrome on its
/// pages' header bars, in step with the element as the tree changes.
/// Design: docs/design/platforms/gtk/runtime.md#the-window
@MainActor
final class GTKWindowController {
    /// The window element shown.
    private(set) weak var element: MountedElement?

    /// The GTK window it is shown in.
    let window: GTKWindow

    /// What the window shows, by the host layer's rule.
    let presentation = WindowPresentation()

    /// A sheet for each page the window's modal stack presents, the last on top.
    private(set) var sheets: [(element: MountedElement, sheet: GTKSheet)] = []

    init(_ element: MountedElement, application: UnsafeMutablePointer<GtkApplication>) {
        self.element = element
        window = GTKWindow(application: application)
    }

    /// Shows what the element asks for now. The host layer tells the page the user sees and the window made before
    /// the window is first shown.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let frame = changes.frame { window.request(frame) }
        if let bounds = changes.bounds { window.bound(bounds) }
        if let hidden = changes.hidden { window.setHidden(hidden) }
        if let (_, arrangement) = changes.arrangement {
            if let arrangement, GTKElement.framedTypes.contains(arrangement.type) {
                window.show(page: arrangement.gtk.view)
            } else {
                window.show(arrangement?.gtk.view)
            }
        }
        if let pages = changes.sheets { showSheets(pages, in: runtime) }
        if let overlays = changes.overlays { window.showOverlays(overlays.compactMap(\.gtk.view)) }
    }

    /// Keeps a sheet for each page presented, in its order: a sheet gone closes, the last first, and one new is shown
    /// over those before it.
    /// Design: docs/design/platforms/gtk/pages.md#sheets
    private func showSheets(_ pages: [MountedElement], in runtime: HostRuntime) {
        let kept = sheets.filter { entry in
            pages.contains { $0 === entry.element && $0.gtk.view === entry.sheet.page }
        }
        for entry in sheets.reversed() where !kept.contains(where: { $0.sheet === entry.sheet }) { entry.sheet.close() }
        sheets = pages.compactMap { page in
            if let entry = kept.first(where: { $0.element === page }) { return entry }
            guard let view = page.gtk.view else { return nil }
            let sheet = GTKSheet(page: view, framed: GTKElement.framedTypes.contains(page.type))
            sheet.onClosedByUser = { [weak self] in self?.dismissTopSheet(in: runtime) }
            sheet.present(over: window)
            return (page, sheet)
        }
    }

    /// The user took the top sheet away - Escape, its close button: the modal stack is told how many remain.
    private func dismissTopSheet(in runtime: HostRuntime) {
        guard let element, !presentation.sheets.isEmpty else { return }
        runtime.goBack(.dismissSheet(remaining: presentation.sheets.count - 1), in: element)
    }

    /// Writes every shown page's chrome on its header bar, and names the window after the page the user sees.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    func refreshChrome() {
        guard let element else { return }

        let arrangement = presentation.arrangement?.gtk
        if let arrangement, GTKElement.framedTypes.contains(arrangement.type) {
            window.pageFrame?.show(arrangement.chrome)
        }
        arrangement?.composeChrome()
        if let split = arrangement?.view as? GTKSplitView { split.adapt(in: window.widget) }
        for (page, sheet) in sheets {
            let chrome = page.gtk.chrome
            sheet.frame?.show(chrome)
            sheet.setTitle(page.visiblePage?.value(.title)?.string ?? chrome.title)
            page.gtk.composeChrome()
        }
        let title = WindowChrome(window: element, arrangement: presentation.arrangement).title
        window.setTitle(title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string)
    }

    /// Goes the way back the window offers (`WindowPresentation.wayBack`), as the user does: a stack's top page goes
    /// in GTK first, the path then told; a sheet goes through the host layer. Whether there was one.
    /// Design: docs/design/host/pages.md#the-way-back
    func goBack(in runtime: HostRuntime) -> Bool {
        guard let element, let way = presentation.wayBack else { return false }
        switch way {
        case .pop(let stack):
            return (stack.gtk.view as? GTKNavigationView)?.popByUser() ?? false
        case .dismissSheet:
            runtime.goBack(way, in: element)
            return true
        }
    }
}
