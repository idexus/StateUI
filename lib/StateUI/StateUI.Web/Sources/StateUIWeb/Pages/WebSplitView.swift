// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A SplitView: its sidebar in an `<aside>` beside the detail, or over it as a drawer where the page is narrow; the
/// shade over the detail takes the drawer away. The sidebar moves in and out, but for the first room's decision.
/// Design: docs/design/platforms/web/pages.md#a-split-view
@MainActor
final class WebSplitView: WebDOMView {
    let sidebar = WebLayoutView(tag: "aside", arrangement: .single)
    let detail = WebLayoutView(arrangement: .single)
    private let scrim = WebDOMView(tag: "div")

    /// Whether the sidebar shows on screen.
    private(set) var isPresented = false

    /// The user showed or hid the sidebar.
    var onPresentationChanged: (Bool) -> Void = { _ in }

    /// The first room it was given decides once whether the sidebar shows.
    private var adaptation = SidebarAdaptation()

    /// The width from which the sidebar stands beside the detail rather than over it - the stylesheet's.
    static let breakpoint = 900.0

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-split")
        sidebar.attribute("class", "stateui-sidebar")
        detail.attribute("class", "stateui-detail")
        scrim.attribute("class", "stateui-scrim")
        WebRelay.insert(sidebar.node, into: node, at: 0)
        WebRelay.insert(scrim.node, into: node, at: 1)
        WebRelay.insert(detail.node, into: node, at: 2)
        scrim.listen("click") { [weak self] in self?.userPresents(false) }
        present(false, moves: false)
    }

    /// Shows the sidebar or hides it, as the tree or the user says; `moves` false for a change that stands at once.
    func present(_ presented: Bool, moves: Bool = true) {
        if presented != isPresented { attribute("data-moves", moves ? "" : nil) }
        isPresented = presented
        attribute("data-sidebar", presented ? "shown" : "hidden")
    }

    /// The user showed or hid the sidebar - the bar's toggle, the shade.
    func userPresents(_ presented: Bool, moves: Bool = true) {
        guard presented != isPresented else { return }
        present(presented, moves: moves)
        onPresentationChanged(presented)
    }

    /// The first room the split view is given: where it is wide, the sidebar shows, as the user's - at once.
    func adapt() {
        let width = WebRelay.box(of: node).width
        if adaptation.room(width, breakpoint: Self.breakpoint, shown: isPresented) { userPresents(true, moves: false) }
    }

    /// Stands the sidebar on what the split view says of each place - beside the detail, and over it - as variables
    /// the style sheet reads in each: a colour, or a blur's filter under its colour; none for the page's own.
    /// Design: docs/design/host/pages.md#a-sidebars-material
    func ground(beside: HostMaterial, over: HostMaterial) {
        for (place, material) in [("sidebar", beside), ("flyout", over)] {
            let box = WebBox(fill: material.paint, material: material.blur == nil ? nil : material)
            let styles = Dictionary(box.styles(size: .zero), uniquingKeysWith: { first, _ in first })
            style("--stateui-\(place)-ground", material.isEmpty ? nil : styles["background"] ?? nil)
            style("--stateui-\(place)-filter", styles["backdrop-filter"] ?? nil)
        }
    }

    override func detach() {
        sidebar.detach()
        detail.detach()
        scrim.detach()
        super.detach()
    }
}
