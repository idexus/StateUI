// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TabView: a strip of its tabs' names over its pages, which stand in one cell, the chosen one shown - the others
/// kept as they stood.
/// Design: docs/design/platforms/web/pages.md#tabs
@MainActor
final class WebTabView: WebDOMView {
    /// Which tab the view shows, by the host layer's rule.
    private(set) var choice = TabChoice()

    /// The user chose a tab: the one shown before, and the one chosen.
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    private let strip = WebDOMView(tag: "div")
    let pages = WebLayoutView(arrangement: .layers)
    private var tabs: [WebDOMView] = []
    private var names: [WebDOMView] = []

    init() {
        super.init(tag: "section")
        attribute("class", "stateui-tabs")
        strip.attribute("class", "stateui-tab-strip")
        strip.attribute("role", "tablist")
        pages.attribute("class", "stateui-tab-pages")
        WebRelay.insert(strip.node, into: node, at: 0)
        WebRelay.insert(pages.node, into: node, at: 1)
    }

    /// The tabs' pages, in order.
    func setTabs(_ views: [WebDOMView]) {
        pages.setItems(views.map { ($0, LayoutValues()) })
        tabs = views
        showChosen()
    }

    /// Names the tabs, and shows the one the tree asks for where the user has not chosen another since.
    func show(_ titles: [String], requested: Int?) {
        while names.count < titles.count { names.append(name(at: names.count)) }
        while names.count > titles.count { names.removeLast().detach() }
        for (index, title) in titles.enumerated() {
            WebRelay.setText(names[index].node, title)
            WebRelay.insert(names[index].node, into: strip.node, at: index)
        }
        _ = choice.request(requested)
        showChosen()
    }

    /// A button naming the tab at `index`, which chooses it.
    private func name(at index: Int) -> WebDOMView {
        let button = WebDOMView(tag: "button")
        button.attribute("type", "button")
        button.attribute("role", "tab")
        button.listen("click") { [weak self] in self?.userChose(index) }
        return button
    }

    /// Chooses a tab as the user's strip does.
    func userChose(_ index: Int) {
        guard let previous = choice.choose(index, of: tabs.count) else { return }
        showChosen()
        onSelection?(previous, index)
    }

    private func showChosen() {
        let shown = choice.shown(among: tabs.count)
        for (index, tab) in tabs.enumerated() { tab.attribute("data-covered", index == shown ? nil : "") }
        for (index, name) in names.enumerated() { name.attribute("aria-selected", index == shown ? "true" : "false") }
    }

    override func detach() {
        for name in names { name.detach() }
        strip.detach()
        pages.detach()
        onSelection = nil
        super.detach()
    }
}
