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

    init(_ element: MountedElement, application: UnsafeMutablePointer<GtkApplication>) {
        self.element = element
        window = GTKWindow(application: application)
    }

    /// Shows what the element asks for now, the window it belongs to found by `windowOf`. The host layer tells the
    /// page the user sees and the window made before the window is first shown.
    func present(_ element: MountedElement, in runtime: HostRuntime, windowOf: (MountedElement) -> GTKWindow?) {
        self.element = element
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let owner = changes.owner { window.setOwner(owner.flatMap(windowOf)) }
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
        if let overlays = changes.overlays { window.showOverlays(overlays.compactMap(\.gtk.view)) }
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
