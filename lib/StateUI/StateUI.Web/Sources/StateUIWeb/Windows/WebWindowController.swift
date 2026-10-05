// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One window element shown in the browser's window: what the host layer says it shows, and the title the browser
/// shows on its tab, in step with the element as the tree changes.
/// Design: docs/design/platforms/web/runtime.md#the-window
@MainActor
final class WebWindowController {
    /// The window element shown.
    private(set) weak var element: MountedElement?

    let window = WebWindow()

    /// What the window shows, by the host layer's rule.
    let presentation = WindowPresentation()

    init(_ element: MountedElement) {
        self.element = element
    }

    /// Shows what the element asks for now.
    func present(_ element: MountedElement, in runtime: HostRuntime) {
        self.element = element
        let changes = presentation.show(element, in: runtime.lifecycle)
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.web.view) }
    }

    /// Names the tab after the page the user sees, else the window.
    func refreshChrome() {
        guard let element else { return }
        let title = WindowChrome(window: element, arrangement: presentation.arrangement).title
        WebRelay.setTitle(title.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string ?? "")
    }
}
