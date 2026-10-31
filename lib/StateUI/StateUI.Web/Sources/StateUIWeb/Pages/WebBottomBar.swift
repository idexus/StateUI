// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar over the page's foot: a holder standing on what stands under the room - a phone's home
/// indicator - its view as tall as it lays out above the page's bar at its foot (`.toolbar(.bottom)`), their height
/// told to the page as it changes, so the page stands clear of them (`standInTheSafeArea`).
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class WebBottomBar {
    /// What stands over the page's foot: the view's holder above the bar at the foot.
    private let foot = WebDOMView(tag: "div")

    /// The view's holder: a layout of one, which stands the bar's view as its values say.
    private let holder = WebLayoutView(tag: "div", arrangement: .single)

    /// The page's bar at its foot, under the view.
    let toolbar = WebBottomToolbar()

    /// The bar's view the holder shows.
    private weak var shown: WebDOMView?

    /// How tall the bar's view and the bar at the foot lay out, in CSS pixels; nought while they show none.
    private(set) var height = 0.0

    /// What the page does as the bar's height changes.
    private let changed: @MainActor () -> Void

    /// A holder over `page`'s foot, telling `changed` as the bar's height changes.
    init(in page: WebDOMView, changed: @escaping @MainActor () -> Void) {
        self.changed = changed
        foot.attribute("class", "stateui-bottom-bar")
        page.style("position", "relative")
        WebRelay.insert(foot.node, into: page.node, at: Int(Int32.max))
        WebRelay.insert(holder.node, into: foot.node, at: 0)
        WebRelay.insert(toolbar.node, into: foot.node, at: 1)
        holder.followSize { [weak self] in self?.measure() }
        toolbar.followSize { [weak self] in self?.measure() }
    }

    /// The bar's element, whose values stand its view.
    private weak var bar: WebElement?

    /// Shows `bar` - the page's bottom bar - and `actions` on the bar at the foot in place of what they showed; nil
    /// for no bar.
    func show(_ bar: WebElement?, toolbar actions: ChromeActions) {
        toolbar.show(actions)
        let view = bar?.view
        if view !== shown {
            (self.bar, shown) = (bar, view)
            holder.setItems(view.map { [($0, { [weak self] in self?.values() ?? LayoutValues() })] } ?? [])
            holder.attribute("hidden", view == nil ? "" : nil)
        }
        foot.attribute("hidden", view == nil && !toolbar.holdsItems ? "" : nil)
        measure()
    }

    /// What the bar's element states of its own place.
    private func values() -> LayoutValues {
        bar?.element.layoutValues ?? LayoutValues()
    }

    /// The scroller whose rows the bar follows, listened to once.
    private weak var followed: WebDOMView?

    /// Whether the page's content runs under the room's foot.
    private var runsUnder = false

    /// The edge the bar shows while rows pass under it.
    private var edge = ScrollEdge.automatic

    /// Follows what of the page stands under the bar - its content where it runs under the room's foot,
    /// `scroller`'s rows as they move - and shows `edge` while anything does.
    func follow(runsUnder: Bool, scroller: WebDOMView?, edge: ScrollEdge) {
        (self.runsUnder, self.edge) = (runsUnder, edge)
        foot.attribute("data-edge", edge == .none ? "none" : edge == .hard ? "hard" : "automatic")
        if let scroller, scroller !== followed {
            scroller.listen("scroll") { [weak self] in self?.standOnGround() }
            // Rows coming and going move the scroller's reach, which no scroll tells.
            (scroller as? WebLayoutView)?.children.first?.followSize { [weak self] in self?.standOnGround() }
        }
        followed = scroller
        standOnGround()
    }

    /// The edge's blur and line while anything stands under the bar (`BottomBarPlace.covers`), but for no edge.
    private func standOnGround() {
        let scroller = followed.map { (offset: WebElement.standing($0), reach: WebElement.reach($0)) }
        let covered = BottomBarPlace.covers(contentRunsUnder: runsUnder, scroller: scroller)
        foot.attribute("data-under", covered && edge != .none ? "" : nil)
    }

    /// Reads the bar's height again, and tells the page where it changed.
    private func measure() {
        let measured = (shown.map { WebRelay.size(of: $0.node).height } ?? 0)
            + (toolbar.holdsItems ? WebRelay.size(of: toolbar.node).height : 0)
        guard measured != height else { return }
        height = measured
        changed()
    }
}
