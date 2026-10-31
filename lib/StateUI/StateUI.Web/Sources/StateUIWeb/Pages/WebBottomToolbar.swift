// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The bar at a page's foot (`.toolbar(.bottom)`), under its view bar: its leading groups at its start, the rest at its
/// end - the window's bar's groups and buttons - as many as fit, the rest and those placed there behind its More
/// (`BarFit`).
/// Design: docs/design/platforms/web/pages.md#the-bar-at-the-foot
@MainActor
final class WebBottomToolbar: WebDOMView {
    private let leading = WebDOMView(tag: "div")
    private let trailing = WebDOMView(tag: "div")

    /// The button opening the actions behind the bar, shown where there are any.
    let more = WebDOMView(tag: "button")
    private let glyph = WebDOMView(tag: "span")
    private var behind: [MenuEntry] = []

    /// The button of each item shown, by the item it stands for.
    private(set) var buttons: [ObjectIdentifier: WebBarButton] = [:]

    /// The groups shown, each a run of buttons standing together, and the items of each in reading order.
    private var groups: [WebBarGroup] = []
    private var runs: [[MountedElement]] = []

    /// The items placed behind the bar.
    private var placed: [MountedElement] = []

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-bottom-toolbar")
        attribute("role", "toolbar")
        for part in [leading, trailing] { part.attribute("class", "stateui-bar-actions") }
        leading.attribute("data-edge", "start")
        let said = CoreLink().chromeWords.more
        more.attribute("type", "button")
        more.attribute("aria-label", said)
        more.attribute("title", said)
        more.attribute("aria-haspopup", "menu")
        glyph.attribute("class", "stateui-glyph")
        glyph.attribute("data-glyph", "more")
        WebRelay.insert(glyph.node, into: more.node, at: 0)
        more.listen("click") { [weak self] in
            guard let self else { return }
            WebMenu(behind).show(under: more)
        }
        WebRelay.insert(leading.node, into: node, at: 0)
        WebRelay.insert(trailing.node, into: node, at: 1)
        followSize { [weak self] in self?.fit() }
        setShown(false)
    }

    /// Whether it holds anything to show.
    var holdsItems: Bool {
        !(runs.isEmpty && placed.isEmpty)
    }

    /// Shows `actions`, each item keeping its button.
    func show(_ actions: ChromeActions) {
        var pool = groups
        var kept: [ObjectIdentifier: WebBarButton] = [:]
        groups = place(actions.start, on: leading, from: &pool, keeping: &kept)
            + place(actions.end, on: trailing, from: &pool, keeping: &kept)
        for (key, button) in buttons where kept[key] == nil { button.release() }
        for gone in pool { gone.release() }
        buttons = kept
        runs = actions.start + actions.end
        placed = actions.overflow
        WebRelay.insert(more.node, into: trailing.node, at: actions.end.count)
        setShown(holdsItems)
        fit()
    }

    /// Stands `runs` on `edge`, each a group of buttons - a group of `pool` taken before one is made, an item's
    /// button the one standing for it - each item's button joining `kept`; the groups standing.
    private func place(
        _ runs: [[MountedElement]], on edge: WebDOMView, from pool: inout [WebBarGroup],
        keeping kept: inout [ObjectIdentifier: WebBarButton]
    ) -> [WebBarGroup] {
        runs.enumerated().map { place, items in
            let group = pool.isEmpty ? WebBarGroup() : pool.removeFirst()
            group.show(items.first?.parent)
            WebRelay.insert(group.node, into: edge.node, at: place)
            for (index, item) in items.enumerated() {
                let button = WebBarButton.standing(for: item, from: &buttons)
                button.show(item)
                WebRelay.insert(button.node, into: group.node, at: index)
                kept[ObjectIdentifier(item)] = button
            }
            return group
        }
    }

    /// Stands as many groups as fit, the first in reading order, and the rest behind More.
    private func fit() {
        let standing = BarFit.standing(groups: groups.count) { trial in
            stand(trial.groups)
            return !WebRelay.crowded(node)
        }
        stand(standing.groups)
    }

    /// The first `count` groups shown, the others' items behind More.
    private func stand(_ count: Int) {
        for (index, group) in groups.enumerated() { group.setShown(index < count) }
        behind = BarFit.behind(left: Array(runs.dropFirst(count)), placed: placed)
        more.setShown(!behind.isEmpty)
    }

    override func release() {
        for button in buttons.values { button.release() }
        for group in groups { group.release() }
        for part in [glyph, more, leading, trailing] { part.release() }
        super.release()
    }
}
