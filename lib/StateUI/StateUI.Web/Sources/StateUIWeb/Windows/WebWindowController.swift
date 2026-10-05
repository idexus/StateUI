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

    init(_ element: MountedElement, runtime: HostRuntime) {
        self.element = element
        window.bar.onBack = { [weak self] in self?.goBack(in: runtime) }
        window.bar.onToggle = { [weak self] in self?.toggleSidebar() }
    }

    /// Shows what the element asks for now; a split view shown is given its first room.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.web.view) }
        (presentation.arrangement?.web.view as? WebSplitView)?.adapt()
    }

    /// Writes the window's chrome on its bar, and names the tab after the page the user sees.
    /// Design: docs/design/platforms/web/pages.md#the-windows-bar
    func refreshChrome() {
        guard let element else { return }
        let chrome = WindowChrome(window: element, arrangement: presentation.arrangement)
        let title = chrome.title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string ?? ""
        window.bar.show(chrome, title: title)
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
    }
}
