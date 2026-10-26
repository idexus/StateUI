// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The window's one bar, over the page the user sees: the sidebar's toggle, the way back, the title area the
/// sidebar's page names the application with, the page's title and the line under it - or the view the page declares
/// in their place - the actions it declares and a menu of those behind it and of its menus - the host layer's
/// `WindowChrome`. Beside a sidebar shown, the bar stands in two parts: over the sidebar the name, the sidebar's part's
/// actions and the toggle, the rest over the detail.
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
    private let words = WebDOMView(tag: "span")
    private let line = WebDOMView(tag: "span")
    private let lead = WebDOMView(tag: "div")
    private let side = WebDOMView(tag: "div")
    private let start = WebDOMView(tag: "div")
    private let leading = WebDOMView(tag: "div")
    private let trailing = WebDOMView(tag: "div")
    private let sideLeading = WebDOMView(tag: "div")
    private let sideTrailing = WebDOMView(tag: "div")

    /// The view standing in place of the title; nil while the title stands there.
    private weak var titleView: WebDOMView?

    /// The button of each action shown, by the item it stands for.
    private(set) var buttons: [ObjectIdentifier: WebBarButton] = [:]

    /// The groups of actions shown over the detail, each a run of buttons standing together, and over the sidebar.
    private var groups: [WebDOMView] = []
    private var sideGroups: [WebDOMView] = []

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

    /// The button opening the actions behind the sidebar's part, shown where there are any.
    private let sideMore = WebDOMView(tag: "button")
    private var sideBehind: [MenuEntry] = []

    /// The items of each group shown, in reading order as `groups` stands; those placed behind the bar; and the
    /// menus the page's path declares - what More offers besides the groups that leave the bar.
    private var runs: [[MountedElement]] = []
    private var placed: [MountedElement] = []
    private var menus: [MenuEntry] = []

    /// The items of each group over the sidebar, in reading order as `sideGroups` stands, and those placed behind
    /// the sidebar's part's More.
    private var sideRuns: [[MountedElement]] = []
    private var sidePlaced: [MountedElement] = []

    init() {
        super.init(tag: "header")
        attribute("class", "stateui-bar")
        attribute("role", "toolbar")
        for (part, kind) in [(brand, "brand"), (heading, "heading"), (name, "name"), (subtitle, "subtitle"),
                             (title, "title"), (words, "words"), (line, "line"), (lead, "lead"), (side, "side"),
                             (start, "start"), (leading, "actions"), (trailing, "actions"), (sideLeading, "actions"),
                             (sideTrailing, "actions")] {
            part.attribute("class", "stateui-bar-\(kind)")
        }
        sideLeading.attribute("data-edge", "start")
        let said = CoreLink().chromeWords
        glyph(toggle, "sidebar", label: said.sidebar)
        glyph(back, "back", label: said.back)
        glyph(closer, "close", label: said.close)
        glyph(more, "more", label: said.more)
        glyph(sideMore, "more", label: said.more)
        for button in [more, sideMore] { button.attribute("aria-haspopup", "menu") }
        more.listen("click") { [weak self] in
            guard let self else { return }
            WebMenu(behind).show(under: more)
        }
        sideMore.listen("click") { [weak self] in
            guard let self else { return }
            WebMenu(sideBehind).show(under: sideMore)
        }
        closer.setShown(false)
        toggle.listen("click") { [weak self] in self?.onToggle() }
        back.listen("click") { [weak self] in self?.onBack() }
        closer.listen("click") { [weak self] in self?.onClose?() }
        for (index, part) in [lead, title, trailing].enumerated() { WebRelay.insert(part.node, into: node, at: index) }
        for (index, part) in [side, start].enumerated() { WebRelay.insert(part.node, into: lead.node, at: index) }
        for (index, part) in [brand, sideLeading, sideTrailing, toggle].enumerated() {
            WebRelay.insert(part.node, into: side.node, at: index)
        }
        for (index, part) in [back, leading].enumerated() { WebRelay.insert(part.node, into: start.node, at: index) }
        WebRelay.insert(heading.node, into: brand.node, at: 0)
        WebRelay.insert(name.node, into: heading.node, at: 0)
        WebRelay.insert(subtitle.node, into: heading.node, at: 1)
        WebRelay.insert(words.node, into: title.node, at: 0)
        WebRelay.insert(line.node, into: title.node, at: 1)
        // The window's width, and the part before the title as a split view's sidebar comes and goes, change what
        // fits.
        followSize { [weak self] in self?.fit() }
        start.followSize { [weak self] in self?.fit() }
        side.followSize { [weak self] in self?.fit() }
    }

    /// The look of the bar's buttons `style` asks for, as the bar's `data-toolbar-style` says it; nil for glass.
    static func look(of style: ToolbarStyle) -> String? {
        switch style {
        case .glass: nil
        case .system, .plain: "plain"
        case .rounded: "rounded"
        }
    }

    /// Shows `chrome`: its parts where it has them, its actions in their groups, its colors; `sidebar` says whether
    /// the split view the toggle serves shows its sidebar, nil where there is none.
    func show(_ chrome: WindowChrome, title shown: String, sidebar: Bool?, split: WebSplitView? = nil) {
        attribute("data-sidebar", sidebar.map { $0 ? "shown" : "hidden" })
        // The part over a sidebar beside the page stands on the sidebar's own ground, as one column with it.
        for name in ["--stateui-sidebar-ground", "--stateui-sidebar-filter"] { style(name, split?.styled(name)) }
        toggle.setShown(chrome.showsSidebarToggle)
        back.setShown(chrome.back != nil)
        back.attribute("title", chrome.back?.title)

        let area = chrome.titleArea
        brand.setShown(area != nil)
        WebRelay.setText(name.node, area?.title ?? "")
        WebRelay.setText(subtitle.node, area?.subtitle ?? "")
        subtitle.setShown(area?.subtitle?.isEmpty == false)
        // A page showing no title leaves its place empty; the tab keeps its name.
        attribute("data-title", chrome.showsTitle ? nil : "none")
        let view = (chrome.center?.native as? WebElement)?.view
        showTitle(chrome.showsTitle ? shown : "", line: chrome.showsTitle ? chrome.subtitle : nil, or: view,
                  repeating: area?.title)

        // The bar's material: a color, or a blur - a backdrop filter under its color - glass drawn as its blur.
        let material = chrome.material
        let box = WebBox(fill: material.paint, material: material.blur == nil ? nil : material)
        let styles = Dictionary(box.styles(size: .zero), uniquingKeysWith: { first, _ in first })
        style("--stateui-bar-background", material.isEmpty ? nil : styles["background"] ?? nil)
        // A clear bar paints nothing, and only softens what scrolls under it toward the top.
        let clear = HostBrush(chrome.background).isClear
        style("--stateui-bar-filter", clear ? "none" : styles["backdrop-filter"] ?? nil)
        attribute("data-clear", clear ? "" : nil)
        // Words the tree gives no color stand light on a dark band and dark on a light one.
        style("--stateui-bar-foreground", WebCSS.color(BandWords.color(on: chrome.background, written: chrome.foreground)))
        // The buttons on glass unless said otherwise: the Web's own look for them, `.system`, is plain.
        attribute("data-toolbar-style", Self.look(of: chrome.toolbarStyle))
        style("--stateui-bar-button", WebCSS.fill(chrome.buttonBackground))

        // An item keeps its button wherever it stands, moving from one part to the other.
        var kept: [ObjectIdentifier: WebBarButton] = [:]
        var pool = sideGroups + groups
        let sidebar = chrome.sidebarActions
        sideGroups = place(sidebar.start, on: sideLeading, from: &pool, keeping: &kept)
            + place(sidebar.end, on: sideTrailing, from: &pool, keeping: &kept)
        let ending = chrome.actions.end
        groups = place(chrome.actions.start, on: leading, from: &pool, keeping: &kept)
            + place(ending, on: trailing, from: &pool, keeping: &kept)
        for (key, button) in buttons where kept[key] == nil { button.release() }
        for gone in pool { gone.release() }
        buttons = kept
        sideRuns = sidebar.start + sidebar.end
        sidePlaced = sidebar.overflow
        // With actions of its own, the part over the sidebar stands its name beside them rather than over them.
        attribute("data-side-acts", sideRuns.isEmpty && sidePlaced.isEmpty ? nil : "")
        WebRelay.insert(sideMore.node, into: sideTrailing.node, at: sidebar.end.count)
        // The bar ends with the actions behind it, then - a sheet's - the button closing it.
        runs = chrome.actions.start + ending
        placed = chrome.actions.overflow
        // A page keeps no Edit menu of its own: one the page joins holds the field's undoing, clipboard and selection.
        menus = chrome.menus
            .editing(CoreLink().editWords, redo: KeyboardShortcut("z", modifiers: [.primary, .shift])).menus
        WebRelay.insert(more.node, into: trailing.node, at: ending.count)
        WebRelay.insert(closer.node, into: trailing.node, at: ending.count + 1)
        fit()
    }

    /// Stands `runs` on `edge`, each a group of buttons - a group of `pool` taken before one is made, an item's
    /// button the one standing for it - each item's button joining `kept`; the groups standing.
    private func place(
        _ runs: [[MountedElement]], on edge: WebDOMView, from pool: inout [WebDOMView],
        keeping kept: inout [ObjectIdentifier: WebBarButton]
    ) -> [WebDOMView] {
        runs.enumerated().map { place, items in
            let group = pool.isEmpty ? WebDOMView(tag: "div") : pool.removeFirst()
            group.attribute("class", "stateui-bar-group")
            group.attribute("role", "group")
            WebRelay.insert(group.node, into: edge.node, at: place)
            for (index, item) in items.enumerated() {
                // A button opens its item's menu one way for good: an item opening it another way is another.
                let opening = ButtonMenu.opening(of: item)
                let standing = buttons.removeValue(forKey: ObjectIdentifier(item))
                if let standing, standing.opening != opening { standing.release() }
                let button = standing.flatMap { $0.opening == opening ? $0 : nil } ?? WebBarButton(opening: opening)
                button.show(item)
                WebRelay.insert(button.node, into: group.node, at: index)
                kept[ObjectIdentifier(item)] = button
            }
            return group
        }
    }

    /// Stands as many groups on the bar as fit beside its title - the first in reading order - and the rest behind
    /// More (`BarFit`); a title left less room than a few letters stands hidden, as an ellipsis alone says nothing.
    /// Design: docs/design/platforms/web/pages.md#a-bar-with-no-room
    private func fit() {
        // The part over the sidebar first: what it holds past its edges would crowd the detail's.
        let sideStanding = BarFit.standing(groups: sideGroups.count) { trial in
            standSide(trial.groups)
            return !WebRelay.crowded(side.node)
        }
        standSide(sideStanding.groups)
        title.attribute("data-squeezed", nil)
        let standing = BarFit.standing(groups: groups.count) { trial in
            stand(trial)
            return !WebRelay.crowded(node)
        }
        stand(standing)
        let squeezed = standing.title == .between && WebRelay.size(of: title.node).width < Self.leastTitle
        title.attribute("data-squeezed", squeezed ? "" : nil)
    }

    /// The groups `standing` keeps on the bar shown, the others' items behind More, and the title as it stands.
    private func stand(_ standing: BarFit.Standing) {
        for (index, group) in groups.enumerated() { group.setShown(index < standing.groups) }
        attribute("data-crowded", standing.title == .between ? "" : nil)
        behind = BarFit.behind(left: Array(runs.dropFirst(standing.groups)), placed: placed)
        if !behind.isEmpty, !menus.isEmpty { behind.append(.separator) }
        behind += menus
        more.setShown(!behind.isEmpty)
    }

    /// The first `count` groups over the sidebar shown, the others' items behind the sidebar's part's More.
    private func standSide(_ count: Int) {
        for (index, group) in sideGroups.enumerated() { group.setShown(index < count) }
        sideBehind = BarFit.behind(left: Array(sideRuns.dropFirst(count)), placed: sidePlaced)
        sideMore.setShown(!sideBehind.isEmpty)
    }

    /// The least room a title stands in: a few letters and an ellipsis, which say what the page is.
    private static let leastTitle = 72.0

    /// The title's words and the `line` under them, or `view` in their place where the page declares one.
    private func showTitle(_ shown: String, line said: String?, or view: WebDOMView?, repeating name: String?) {
        if let titleView, titleView !== view, !titleView.isReleased { WebRelay.detach(titleView.node) }
        titleView = view
        if let view { WebRelay.insert(view.node, into: title.node, at: 0) }
        WebRelay.setText(words.node, view == nil ? shown : "")
        WebRelay.setText(line.node, view == nil ? said ?? "" : "")
        words.setShown(view == nil)
        line.setShown(view == nil && said != nil)
        title.setShown(view != nil || !shown.isEmpty)
        title.attribute("data-repeats", view == nil && shown == name && said == nil ? "" : nil)
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

    override func release() {
        for button in buttons.values { button.release() }
        for group in groups + sideGroups { group.release() }
        for shape in glyphs { shape.release() }
        let parts = [
            toggle, back, closer, more, sideMore, name, subtitle, heading, brand, words, line, title, leading, trailing,
            sideLeading, sideTrailing, side, start, lead,
        ]
        for part in parts {
            part.release()
        }
        super.release()
    }
}
