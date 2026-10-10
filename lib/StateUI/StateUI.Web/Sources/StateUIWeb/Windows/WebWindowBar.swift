// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The window's one bar, over the page the user sees: the sidebar's toggle, the way back, the application's name,
/// the page's title - or the view the page declares in its place - the actions its path declares and a menu of those behind it and of its menus - the
/// host layer's `WindowChrome`. Beside a sidebar shown, the bar stands in two parts: the name and the toggle over the
/// sidebar, the rest over the detail.
/// Design: docs/design/platforms/web/pages.md#the-windows-bar
@MainActor
final class WebWindowBar: WebDOMView {
    private let toggle = WebDOMView(tag: "button")
    private let back = WebDOMView(tag: "button")
    private let brand = WebDOMView(tag: "div")
    private let heading = WebDOMView(tag: "div")
    private let name = WebDOMView(tag: "span")
    private let subtitle = WebDOMView(tag: "span")
    private let title = WebDOMView(tag: "span")
    private let lead = WebDOMView(tag: "div")
    private let side = WebDOMView(tag: "div")
    private let start = WebDOMView(tag: "div")
    private let leading = WebDOMView(tag: "div")
    private let trailing = WebDOMView(tag: "div")

    /// The view standing in place of the title; nil while the title stands there.
    private weak var titleView: WebDOMView?

    /// The button of each action shown, by the item it stands for.
    private(set) var buttons: [ObjectIdentifier: WebBarButton] = [:]

    /// The groups of actions shown, each a run of buttons standing together.
    private var groups: [WebDOMView] = []

    /// The shape drawn on each button of the bar's own, let go of with the bar.
    private var glyphs: [WebDOMView] = []

    /// What the toggle and the way back do.
    var onToggle: () -> Void = {}
    var onBack: () -> Void = {}

    /// What the button closing a sheet does; nil for a window's bar, which has none.
    var onClose: (() -> Void)? {
        didSet { closer.setShown(onClose != nil) }
    }
    private let closer = WebDOMView(tag: "button")

    /// The button opening the actions that stand behind the bar - its overflow - and the menus the page's path
    /// declares; shown where there are any.
    private let more = WebDOMView(tag: "button")
    private var behind: [MenuEntry] = []

    init() {
        super.init(tag: "header")
        attribute("class", "stateui-bar")
        attribute("role", "toolbar")
        for (part, kind) in [(brand, "brand"), (heading, "heading"), (name, "name"), (subtitle, "subtitle"),
                             (title, "title"), (lead, "lead"), (side, "side"), (start, "start"),
                             (leading, "actions"), (trailing, "actions")] {
            part.attribute("class", "stateui-bar-\(kind)")
        }
        glyph(toggle, "sidebar", label: "Sidebar")
        glyph(back, "back", label: "Back")
        glyph(closer, "close", label: "Close")
        glyph(more, "more", label: "More")
        more.attribute("aria-haspopup", "menu")
        more.listen("click") { [weak self] in
            guard let self else { return }
            WebMenu(behind).show(under: more)
        }
        closer.setShown(false)
        toggle.listen("click") { [weak self] in self?.onToggle() }
        back.listen("click") { [weak self] in self?.onBack() }
        closer.listen("click") { [weak self] in self?.onClose?() }
        for (index, part) in [lead, title, trailing].enumerated() { WebRelay.insert(part.node, into: node, at: index) }
        for (index, part) in [side, start].enumerated() { WebRelay.insert(part.node, into: lead.node, at: index) }
        for (index, part) in [brand, toggle].enumerated() { WebRelay.insert(part.node, into: side.node, at: index) }
        for (index, part) in [back, leading].enumerated() { WebRelay.insert(part.node, into: start.node, at: index) }
        WebRelay.insert(heading.node, into: brand.node, at: 0)
        WebRelay.insert(name.node, into: heading.node, at: 0)
        WebRelay.insert(subtitle.node, into: heading.node, at: 1)
    }

    /// Shows `chrome`: its parts where it has them, its actions in their groups, its colours; `sidebar` says whether
    /// the split view the toggle serves shows its sidebar, nil where there is none.
    func show(_ chrome: WindowChrome, title shown: String, sidebar: Bool?, split: WebSplitView? = nil) {
        attribute("data-sidebar", sidebar.map { $0 ? "shown" : "hidden" })
        // The part over a sidebar beside the page stands on the sidebar's own ground, as one column with it.
        for name in ["--stateui-sidebar-ground", "--stateui-sidebar-filter"] { style(name, split?.styled(name)) }
        toggle.setShown(chrome.sidebarToggle != nil)
        back.setShown(chrome.back != nil)
        back.attribute("title", chrome.back?.title)

        let area = chrome.titleArea
        brand.setShown(area != nil)
        WebRelay.setText(name.node, area?.title ?? "")
        WebRelay.setText(subtitle.node, area?.subtitle ?? "")
        subtitle.setShown(area?.subtitle?.isEmpty == false)
        showTitle(shown, or: (chrome.center?.native as? WebElement)?.view, repeating: area?.title)

        style("--stateui-bar-background", WebCSS.fill(chrome.background))
        // A clear bar shows what is behind it as it is: no blur, no deeper colour under it.
        style("--stateui-bar-filter", HostBrush(chrome.background).isClear ? "none" : nil)
        // Words the tree gives no colour stand light on a dark band and dark on a light one.
        style("--stateui-bar-foreground", WebCSS.color(BandWords.color(on: chrome.background, written: chrome.foreground)))

        var kept: [ObjectIdentifier: WebBarButton] = [:]
        var made: [WebDOMView] = []
        let ending = chrome.actions.trailing
        for (edge, runs) in [(leading, chrome.actions.leading), (trailing, ending)] {
            for (place, items) in runs.enumerated() {
                let group = place < groups.count ? groups.removeFirst() : WebDOMView(tag: "div")
                group.attribute("class", "stateui-bar-group")
                group.attribute("role", "group")
                WebRelay.insert(group.node, into: edge.node, at: place)
                for (index, item) in items.enumerated() {
                    let button = buttons[ObjectIdentifier(item)] ?? WebBarButton()
                    button.show(item)
                    WebRelay.insert(button.node, into: group.node, at: index)
                    kept[ObjectIdentifier(item)] = button
                }
                made.append(group)
            }
        }
        for (key, button) in buttons where kept[key] == nil { button.detach() }
        for gone in groups { gone.detach() }
        buttons = kept
        groups = made
        // The bar ends with the actions behind it, then - a sheet's - the button closing it.
        behind = chrome.actions.overflow.map(MenuEntry.entry(of:))
        if !behind.isEmpty, !chrome.menus.menus.isEmpty { behind.append(.separator) }
        behind += chrome.menus.menus
        more.setShown(!behind.isEmpty)
        WebRelay.insert(more.node, into: trailing.node, at: ending.count)
        WebRelay.insert(closer.node, into: trailing.node, at: ending.count + 1)
    }

    /// The title's words, or `view` in their place where the page declares one.
    private func showTitle(_ words: String, or view: WebDOMView?, repeating name: String?) {
        if let titleView, titleView !== view, !titleView.isReleased { WebRelay.detach(titleView.node) }
        titleView = view
        if let view {
            WebRelay.setText(title.node, "")
            WebRelay.insert(view.node, into: title.node, at: 0)
        } else {
            WebRelay.setText(title.node, words)
        }
        title.setShown(view != nil || !words.isEmpty)
        title.attribute("data-repeats", view == nil && words == name ? "" : nil)
        title.attribute("data-holds-view", view == nil ? nil : "")
    }

    private func glyph(_ button: WebDOMView, _ glyph: String, label: String) {
        button.attribute("type", "button")
        button.attribute("aria-label", label)
        button.attribute("title", label)
        let shape = WebDOMView(tag: "span")
        shape.attribute("class", "stateui-glyph")
        shape.attribute("data-glyph", glyph)
        WebRelay.insert(shape.node, into: button.node, at: 0)
        glyphs.append(shape)
    }

    override func detach() {
        for button in buttons.values { button.detach() }
        for group in groups { group.detach() }
        for shape in glyphs { shape.detach() }
        let parts = [
            toggle, back, closer, more, name, subtitle, heading, brand, title, leading, trailing, side, start, lead,
        ]
        for part in parts {
            part.detach()
        }
        super.detach()
    }
}
