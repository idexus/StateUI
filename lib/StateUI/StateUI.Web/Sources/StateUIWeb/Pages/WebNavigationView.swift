// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A NavigationStack: its pages one over another in one cell, the top one shown - those beneath kept, as they
/// stood, scrolled where the user left them - and a page pushed arriving.
/// Design: docs/design/platforms/web/pages.md#a-stack
@MainActor
final class WebNavigationView: WebLayoutView {
    /// The pages, bottom first, as last shown.
    private var pages: [WebDOMView] = []

    init() {
        super.init(arrangement: .single)
        attribute("class", "stateui-stack")
    }

    /// Stands the pages in the cell, the top one alone shown; one new on top arrives.
    func show(_ pages: [WebDOMView]) {
        let pushed = pages.count > self.pages.count && self.pages.allSatisfy { page in pages.contains { $0 === page } }
        setItems(pages.map { ($0, LayoutValues()) })
        for (index, page) in pages.enumerated() {
            let top = index == pages.count - 1
            page.attribute("data-covered", top ? nil : "")
            page.attribute("data-arriving", top && pushed ? "" : nil)
        }
        self.pages = pages
    }
}
