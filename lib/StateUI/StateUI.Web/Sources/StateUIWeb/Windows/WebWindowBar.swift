// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The window's one bar, over the page the user sees: the sidebar's toggle, the way back, the application's name
/// and mark, the page's title, and the actions its path declares - the host layer's `WindowChrome`. Beside a sidebar
/// shown, the bar stands in two parts: the name and the toggle over the sidebar, the rest over the detail.
/// Design: docs/design/platforms/web/pages.md#the-windows-bar
@MainActor
final class WebWindowBar: WebDOMView {
    private let toggle = WebDOMView(tag: "button")
    private let back = WebDOMView(tag: "button")
    private let brand = WebDOMView(tag: "div")
    private let mark = WebImageView()
    private let heading = WebDOMView(tag: "div")
    private let name = WebDOMView(tag: "span")
    private let subtitle = WebDOMView(tag: "span")
    private let title = WebDOMView(tag: "span")
    private let lead = WebDOMView(tag: "div")
    private let side = WebDOMView(tag: "div")
    private let start = WebDOMView(tag: "div")
    private let leading = WebDOMView(tag: "div")
    private let trailing = WebDOMView(tag: "div")

    /// The button of each action shown, by the item it stands for.
    private var buttons: [ObjectIdentifier: WebBarButton] = [:]

    /// What the toggle and the way back do.
    var onToggle: () -> Void = {}
    var onBack: () -> Void = {}

    /// What the button closing a sheet does; nil for a window's bar, which has none.
    var onClose: (() -> Void)? {
        didSet { closer.setShown(onClose != nil) }
    }
    private let closer = WebDOMView(tag: "button")

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
        closer.setShown(false)
        toggle.listen("click") { [weak self] in self?.onToggle() }
        back.listen("click") { [weak self] in self?.onBack() }
        closer.listen("click") { [weak self] in self?.onClose?() }
        for (index, part) in [lead, title, trailing].enumerated() { WebRelay.insert(part.node, into: node, at: index) }
        for (index, part) in [side, start].enumerated() { WebRelay.insert(part.node, into: lead.node, at: index) }
        for (index, part) in [brand, toggle].enumerated() { WebRelay.insert(part.node, into: side.node, at: index) }
        for (index, part) in [back, leading].enumerated() { WebRelay.insert(part.node, into: start.node, at: index) }
        WebRelay.insert(mark.node, into: brand.node, at: 0)
        WebRelay.insert(heading.node, into: brand.node, at: 1)
        WebRelay.insert(name.node, into: heading.node, at: 0)
        WebRelay.insert(subtitle.node, into: heading.node, at: 1)
    }

    /// Shows `chrome`: its parts where it has them, its actions in their groups, its colours; `sidebar` says whether
    /// the split view the toggle serves shows its sidebar, nil where there is none.
    func show(_ chrome: WindowChrome, title shown: String, sidebar: Bool?) {
        attribute("data-sidebar", sidebar.map { $0 ? "shown" : "hidden" })
        toggle.setShown(chrome.sidebarToggle != nil)
        back.setShown(chrome.back != nil)
        back.attribute("title", chrome.back?.title)

        let area = chrome.titleArea
        brand.setShown(area != nil)
        WebRelay.setText(name.node, area?.title ?? "")
        WebRelay.setText(subtitle.node, area?.subtitle ?? "")
        subtitle.setShown(area?.subtitle?.isEmpty == false)
        mark.apply(source: area?.icon.map { ImageSource($0) }, aspect: .fit)
        mark.setShown(area?.icon?.isEmpty == false)
        WebRelay.setText(title.node, shown)
        title.setShown(!shown.isEmpty)
        title.attribute("data-repeats", shown == area?.title ? "" : nil)

        style("--stateui-bar-background", WebCSS.fill(chrome.background))
        style("--stateui-bar-foreground", WebCSS.color(chrome.foreground))

        var kept: [ObjectIdentifier: WebBarButton] = [:]
        let ending = chrome.actions.trailing + [chrome.actions.overflow]
        for (edge, groups) in [(leading, chrome.actions.leading), (trailing, ending)] {
            let items = groups.flatMap { $0 }
            for (index, item) in items.enumerated() {
                let button = buttons[ObjectIdentifier(item)] ?? WebBarButton()
                button.show(item)
                WebRelay.insert(button.node, into: edge.node, at: index)
                kept[ObjectIdentifier(item)] = button
            }
        }
        for (key, button) in buttons where kept[key] == nil { button.detach() }
        buttons = kept
        // A sheet's bar ends with the button closing it, after its own actions.
        WebRelay.insert(closer.node, into: trailing.node, at: ending.joined().count)
    }

    private func glyph(_ button: WebDOMView, _ glyph: String, label: String) {
        button.attribute("type", "button")
        button.attribute("aria-label", label)
        button.attribute("title", label)
        let shape = WebDOMView(tag: "span")
        shape.attribute("class", "stateui-glyph")
        shape.attribute("data-glyph", glyph)
        WebRelay.insert(shape.node, into: button.node, at: 0)
    }

    override func detach() {
        for button in buttons.values { button.detach() }
        let parts = [toggle, back, closer, mark, name, subtitle, heading, brand, title, leading, trailing, side, start, lead]
        for part in parts {
            part.detach()
        }
        super.detach()
    }
}
