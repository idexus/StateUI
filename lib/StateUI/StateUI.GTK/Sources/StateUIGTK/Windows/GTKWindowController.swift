// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// One window element shown in a GTK window: what the host layer says it shows - its arrangement of pages, its
/// overlays, its size, its bounds and whether its scene hides it - and the chrome on its
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

    /// A sheet for each page the window's views present, the last shown on top.
    private(set) var sheets: [(element: MountedElement, sheet: GTKSheet)] = []

    /// The shortcuts of the window's bar items and menu bar entries.
    let shortcuts: GTKWindowShortcuts

    /// The keys a view takes, before the widget holding the focus has them.
    let keys: GTKWindowKeys

    private weak var runtime: HostRuntime?

    init(_ element: MountedElement, application: UnsafeMutablePointer<GtkApplication>) {
        self.element = element
        window = GTKWindow(application: application)
        shortcuts = GTKWindowShortcuts(on: window.widget)
        keys = GTKWindowKeys(on: window.widget)
        shortcuts.onPressed = { [weak self] in self?.choose(by: $0) == true }
        keys.onPressed = { [weak self] in self?.take($0) == true }
    }

    /// Shows what the element asks for now. The host layer tells the page the user sees and the window made before
    /// the window is first shown.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        self.runtime = runtime
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let traits = changes.traits {
            window.setBackground(traits.background.painted)
            // The surfaces over the page stand on it too: the sheets, and the sidebars over the detail.
            for (page, sheet) in sheets { sheet.stand(on: page.overlaidGround) }
            for split in element.splitViews { (split.native as? GTKElement)?.groundSidebar() }
        }
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
        for (page, sheet) in sheets {
            sheet.stand(at: SheetSize.size(of: page, in: GTKSheet.room(in: window)) { width in
                page.gtk.layoutItem?.size(offered: width) ?? LayoutSize(width: 0, height: 0)
            })
        }
        if let overlays = changes.overlays { window.showOverlays(overlays.compactMap(\.gtk.view)) }
    }

    /// Keeps a sheet for each page presented, in its order, by the host layer's rule (`SheetChange`): a sheet gone
    /// closes, the top first, and one new is shown over those before it.
    /// Design: docs/design/platforms/gtk/pages.md#sheets
    private func showSheets(_ pages: [MountedElement], in runtime: HostRuntime) {
        let change = SheetChange(from: sheets, to: pages) { $0.element === $1 && $1.gtk.view === $0.sheet.page }
        for entry in change.leaving { entry.sheet.close() }
        sheets.removeLast(sheets.count - change.kept)
        for page in change.coming {
            guard let view = page.gtk.view else { continue }
            // A page stands on the dialog alone - a sheet has no bar of its own; a tabbed view in the frame its
            // switcher stands in.
            let sheet = GTKSheet(page: view, framed: page.type == .tabView)
            sheet.onClosedByUser = { [weak self] in self?.dismissTopSheet(in: runtime) }
            sheet.stand(on: page.overlaidGround)
            sheet.present(over: window)
            sheets.append((page, sheet))
        }
    }

    /// The user took the top sheet away - Escape, its close button: false is written onto its state.
    private func dismissTopSheet(in runtime: HostRuntime) {
        guard let element, !presentation.sheets.isEmpty else { return }
        runtime.goBack(.dismissSheets(Array(presentation.sheets.suffix(1))), in: element)
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
        for (page, sheet) in sheets {
            let chrome = page.gtk.chrome
            sheet.frame?.show(chrome)
            sheet.setTitle(page.visiblePage?.value(.title)?.string ?? chrome.title)
            page.gtk.composeChrome()
        }
        let title = WindowChrome(window: element, arrangement: presentation.arrangement).title
        window.setTitle(title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string)
        shortcuts.hold(KeyboardShortcuts.stated(under: element))
    }

    /// A key a view takes, sent to it (`KeyPresses`): out from the view holding the focus, else from the page in
    /// front. Whether one took it.
    private func take(_ pressed: KeyboardShortcut) -> Bool {
        guard let element, let runtime else { return false }
        let focus = gtk_widget_get_root(window.widget).flatMap { gtk_root_get_focus($0) }
        let holder = KeyPresses.holder(under: element) { held in
            guard let focus, let widget = (held.native as? GTKElement)?.view?.widget else { return false }
            return focus == widget || gtk_widget_is_ancestor(focus, widget) != 0
        }
        return KeyPresses.press(
            pressed.key, modifiers: pressed.modifiers, focused: holder, front: presentation.frontPage, in: runtime)
    }

    /// A bar's item or a menu bar's entry chosen by a shortcut pressed in the window, unless it gives way to typing
    /// while a field is typed into; a button's shortcut is its own controller's. Whether one took it.
    private func choose(by shortcut: KeyboardShortcut) -> Bool {
        guard let element, let runtime,
              let target = KeyboardShortcuts.target(of: shortcut, under: element), target.type != .button,
              !(KeyboardShortcuts.givesWayToTyping(shortcut) && GTKKeys.typing(in: window.widget))
        else { return false }
        target.chosen(in: runtime)
        return true
    }

    /// Goes the way back the window offers (`WindowPresentation.wayBack`), as the user does: a stack's top page goes
    /// in GTK first, the path then told; a sheet goes through the host layer. Whether there was one.
    /// Design: docs/design/host/pages.md#the-way-back
    func goBack(in runtime: HostRuntime) -> Bool {
        guard let element, let way = presentation.wayBack else { return false }
        switch way {
        case .pop(let stack):
            return (stack.gtk.view as? GTKNavigationView)?.popByUser() ?? false
        case .dismissSheets:
            runtime.goBack(way, in: element)
            return true
        }
    }
}
