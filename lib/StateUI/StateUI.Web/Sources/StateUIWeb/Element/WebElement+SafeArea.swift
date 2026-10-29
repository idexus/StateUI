// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page against what stands over its room - the depths the stylesheet passes down as `--stateui-over-*`.
/// Design: docs/design/platforms/web/pages.md#the-safe-area
extension WebElement {
    /// Shows a page's bottom bar - the one declared innermost on its path - over its foot, and stands the page clear
    /// of it.
    func showBottomBar() {
        guard type == .page, let view else { return }
        let shown = element.chromeBottomBar?.web.placedElement
        guard shown != nil || bottomBar != nil else { return }
        let bar = bottomBar ?? WebBottomBar(in: view) { [weak self] in self?.standInTheSafeArea() }
        bottomBar = bar
        bar.show(shown)
    }

    /// Stands the page's content clear of what stands over it - its bottom bar included - but on an edge where the
    /// content ignores the safe area (`SafeAreaArithmetic.under`); a scroller let under keeps it as its own padding,
    /// its first and last rows clear, and one at its end stays there (`ScrollArithmetic.keptAtEnd`).
    func standInTheSafeArea() {
        guard type == .page, let view else { return }
        let under = SafeAreaArithmetic.under(element.contentIgnoresSafeArea, direction: element.layoutDirection)
        let scroller = element.pageScroller?.web.view
        let foot = bottomBar?.height ?? 0
        let (standing, before) = (scroller.map(Self.standing) ?? .zero, scroller.map(Self.reach) ?? .zero)
        let edges = [("top", under.top), ("left", under.left), ("bottom", under.bottom), ("right", under.right)]
        for (edge, runsUnder) in edges {
            let depth = edge == "bottom" && foot > 0
                ? "calc(var(--stateui-over-bottom) + \(WebCSS.pixels(foot) ?? "0px"))" : "var(--stateui-over-\(edge))"
            view.style("padding-\(edge)", runsUnder ? nil : depth)
            scroller?.style("padding-\(edge)", runsUnder ? depth : nil)
        }
        if let scroller, let end = ScrollArithmetic.keptAtEnd(standing, reach: before, now: Self.reach(scroller)) {
            WebRelay.setNumber(scroller.node, "scrollLeft", end.x)
            WebRelay.setNumber(scroller.node, "scrollTop", end.y)
        }
        bottomBar?.follow(runsUnder: under.bottom, scroller: scroller)
        // What stands in the page has nothing over it on an edge the page stands its content clear of.
        let pads = edges.filter { !$0.1 }.map(\.0).joined(separator: " ")
        view.attribute("data-pads", pads.isEmpty ? nil : pads)
    }

    /// Where a scroller stands, in CSS pixels.
    static func standing(_ scroller: WebDOMView) -> Point {
        Point(x: WebRelay.number(of: scroller.node, "scrollLeft"), y: WebRelay.number(of: scroller.node, "scrollTop"))
    }

    /// The farthest a scroller stands, in CSS pixels: its content and its padding past its viewport.
    static func reach(_ scroller: WebDOMView) -> Point {
        let number = { (name: String) in WebRelay.number(of: scroller.node, name) }
        return Point(
            x: max(0, number("scrollWidth") - number("clientWidth")), y: max(0, number("scrollHeight") - number("clientHeight")))
    }
}
