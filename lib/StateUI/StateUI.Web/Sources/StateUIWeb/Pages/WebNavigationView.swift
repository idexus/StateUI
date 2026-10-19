// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A NavigationStack: its pages one over another in one cell, the top one shown - those beneath kept, as they
/// stood, scrolled where the user left them - a page pushed arriving and one popped back to returning.
/// Design: docs/design/platforms/web/pages.md#a-stack
@MainActor
final class WebNavigationView: WebLayoutView {
    /// The pages, bottom first, as last shown.
    private var pages: [WebDOMView] = []

    init() {
        super.init(arrangement: .single)
        attribute("class", "stateui-stack")
    }

    /// Stands the pages in the cell, the top one alone shown: one pushed arrives, one popped back to returns, as
    /// the host layer says the path changed (`PathChange`).
    func show(_ pages: [WebDOMView]) {
        let change = PathChange.of(from: self.pages, to: pages, same: ===)
        let returning = if case .pop? = change { true } else { false }
        setItems(pages.map { ($0, { LayoutValues() }) })
        for (index, page) in pages.enumerated() {
            let top = index == pages.count - 1
            page.attribute("data-covered", top ? nil : "")
            page.attribute("data-arriving", top && change == .push ? "" : nil)
            page.attribute("data-returning", top && returning ? "" : nil)
        }
        self.pages = pages
    }
}
