// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page against what stands over its room - the depths the stylesheet passes down as `--stateui-over-*`.
/// Design: docs/design/platforms/web/pages.md#the-safe-area
extension WebElement {
    /// Stands the page's content clear of what stands over it, but on an edge where the content lets itself under
    /// (`SafeAreaArithmetic.under`); a scroller let under keeps it as its own padding, its first and last rows clear.
    func standInTheSafeArea() {
        guard type == .page, let view else { return }
        let under = SafeAreaArithmetic.under(element.contentSafeArea, direction: element.layoutDirection)
        let scroller = element.pageScroller?.web.view
        for (edge, runsUnder) in [("top", under.top), ("left", under.left), ("bottom", under.bottom), ("right", under.right)] {
            let depth = "var(--stateui-over-\(edge))"
            view.style("padding-\(edge)", runsUnder ? nil : depth)
            scroller?.style("padding-\(edge)", runsUnder ? depth : nil)
        }
    }
}
