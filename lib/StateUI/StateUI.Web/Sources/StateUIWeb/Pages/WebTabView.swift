// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TabView: a strip of its tabs - each its picture beside its name - over its pages, which stand in one cell, the
/// chosen one shown - the others kept as they stood.
/// Design: docs/design/platforms/web/pages.md#tabs
@MainActor
final class WebTabView: WebDOMView {
    /// Which tab the view shows, by the host layer's rule.
    private(set) var choice = TabChoice()

    /// The user chose a tab: the one shown before, and the one chosen.
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    let strip = WebDOMView(tag: "div")
    let pages = WebLayoutView(arrangement: .layers)
    private var tabs: [WebDOMView] = []
    private var names: [WebDOMView] = []
    private var pictures: [WebImageView] = []
    private var words: [WebDOMView] = []

    init() {
        super.init(tag: "section")
        attribute("class", "stateui-tabs")
        strip.attribute("class", "stateui-tab-strip")
        strip.attribute("role", "tablist")
        pages.attribute("class", "stateui-tab-pages")
        WebRelay.insert(strip.node, into: node, at: 0)
        WebRelay.insert(pages.node, into: node, at: 1)
    }

    /// Paints the strip as the bars on its path are painted - their colour, and no blur under a clear one - so it
    /// stands as one with the window's bar; the bar's own look where nothing is said.
    /// Design: docs/design/platforms/web/pages.md#tabs
    func showColors(background: HostValue?) {
        strip.style("--stateui-bar-background", WebCSS.fill(background))
        strip.style("--stateui-bar-filter", HostBrush(background).isClear ? "none" : nil)
    }

    /// The tabs' pages, in order.
    func setTabs(_ views: [WebDOMView]) {
        pages.setItems(views.map { ($0, LayoutValues()) })
        tabs = views
        showChosen()
    }

    /// Names the tabs and gives them their pictures - none for an empty name - and shows the one the tree asks for
    /// where the user has not chosen another since.
    func show(_ titles: [String], icons: [String], requested: Int?) {
        while names.count < titles.count { names.append(name(at: names.count)) }
        while names.count > titles.count {
            names.removeLast().detach()
            pictures.removeLast().detach()
            words.removeLast().detach()
        }
        for (index, title) in titles.enumerated() {
            let icon = index < icons.count ? icons[index] : ""
            pictures[index].apply(source: icon.isEmpty ? nil : ImageSource(icon), aspect: .fit)
            pictures[index].setShown(!icon.isEmpty)
            WebRelay.setText(words[index].node, title)
            WebRelay.insert(names[index].node, into: strip.node, at: index)
        }
        _ = choice.request(requested)
        showChosen()
    }

    /// A button naming the tab at `index` - its picture, then its words - which chooses it.
    private func name(at index: Int) -> WebDOMView {
        let button = WebDOMView(tag: "button")
        button.attribute("type", "button")
        button.attribute("role", "tab")
        let (picture, said) = (WebImageView(), WebDOMView(tag: "span"))
        WebRelay.insert(picture.node, into: button.node, at: 0)
        WebRelay.insert(said.node, into: button.node, at: 1)
        pictures.append(picture)
        words.append(said)
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
        // The keyboard comes to the chosen tab alone; the arrows go on from it to the others.
        for (index, name) in names.enumerated() {
            name.attribute("aria-selected", index == shown ? "true" : "false")
            name.attribute("tabindex", index == shown ? "0" : "-1")
        }
    }

    override func detach() {
        for picture in pictures { picture.detach() }
        for said in words { said.detach() }
        for name in names { name.detach() }
        strip.detach()
        pages.detach()
        onSelection = nil
        super.detach()
    }
}
