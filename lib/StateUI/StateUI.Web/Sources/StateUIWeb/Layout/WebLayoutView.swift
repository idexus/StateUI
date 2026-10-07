// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A StateUI layout over the browser's own: a stack is a flexbox, a grid a CSS grid, a ZStack one cell its children
/// share, a page or a window's room a grid of one cell. The browser measures and places; each child's margin,
/// alignments and sizes are written as its CSS.
/// Design: docs/design/platforms/web/layout.md#a-layout-is-the-browsers
@MainActor
class WebLayoutView: WebDOMView {
    /// How the layout sets its children.
    enum Arrangement: Equatable {
        /// One after another along an axis, a flexbox.
        case stack(StackArithmetic.Axis)

        /// One child in the whole room, a grid of one cell.
        case single

        /// In the cells of rows and columns, a CSS grid.
        case grid

        /// One over another, each in its area or where a placing run puts it.
        case layers
    }

    let arrangement: Arrangement

    /// The children's views and what each one's place reads, in order.
    private(set) var children: [WebDOMView] = []
    private var values: [LayoutValues] = []

    /// Each child's mounted element, by number, and how it fades in as it joins: what its place travels by.
    private var travellers: [(mount: UInt64, fadeIn: ((Motion) -> Void)?)] = []

    /// Where the children travel to their places, and who reads their places on the page; nil while they stand at
    /// once wherever the browser lays them out.
    let places = TravellingPlaces()
    weak var placing: WebPlacements?

    /// A grid's tracks as the element defines them.
    private var rows: [GridLength] = []
    private var columns: [GridLength] = []

    /// The room inside the layout's edge, which a ZStack's areas stand in.
    private var padding = Insets(0)

    /// A ZStack's placing run; nil while each child stands in its own area.
    private var placement: HostPlacementRun?

    /// The ways the layout scrolls its child, which there is no larger than its room.
    var scrolls = (across: false, down: false) {
        didSet { if scrolls != oldValue { placeAll() } }
    }

    init(tag: String = "div", arrangement: Arrangement) {
        self.arrangement = arrangement
        super.init(tag: tag)
        switch arrangement {
        case .stack(let axis):
            style("display", "flex")
            style("flex-direction", axis == .vertical ? "column" : "row")
        case .single, .layers:
            style("display", "grid")
            style("grid-template", "minmax(0, 1fr) / minmax(0, 1fr)")
            if arrangement == .layers { style("position", "relative") }
        case .grid:
            style("display", "grid")
        }
    }

    /// The room left between the children of a stack.
    func setSpacing(_ spacing: Double) {
        style("gap", spacing == 0 ? nil : WebCSS.pixels(spacing))
    }

    /// The room left between a grid's rows and between its columns.
    func setGridSpacing(rows: Double, columns: Double) {
        style("row-gap", rows == 0 ? nil : WebCSS.pixels(rows))
        style("column-gap", columns == 0 ? nil : WebCSS.pixels(columns))
    }

    /// A grid's tracks, written with its children's cells.
    func setTracks(rows: [GridLength], columns: [GridLength]) {
        self.rows = rows
        self.columns = columns
        writeTracks()
    }

    override func setPadding(_ padding: Insets?) {
        self.padding = padding ?? Insets(0)
        super.setPadding(padding)
    }

    /// The layout's own box: what fills it, its outline inside its edge, its shape, and whether it cuts what it holds.
    func setBox(background: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?, clips: Bool) {
        let material = HostMaterial(background)
        setBox(WebBox(
            fill: material.paint, stroke: stroke, lineWidth: lineWidth, shape: shape,
            material: material.blur == nil ? nil : material))
        style("overflow", clips ? "hidden" : nil)
    }

    /// Whether a click beside the layout's children goes on to what is under it; one on a child stays the child's.
    func setLetsInputThrough(_ lets: Bool) {
        attribute("data-lets-through", lets ? "" : nil)
    }

    /// What fills the layout's box.
    override func setBackground(_ value: HostValue?) {
        let material = HostMaterial(value)
        var box = paintedBox
        box.fill = material.paint
        box.material = material.blur == nil ? nil : material
        setBox(box)
    }

    /// Where a ZStack's placing run puts its children; nil to stand each in its own area.
    func setPlacement(_ run: HostPlacementRun?) {
        guard run != placement else { return }
        placement = run
        placeAll()
    }

    /// Puts `items` in the element in their order, where it holds them otherwise, and writes each one's place; a
    /// child this layout no longer holds leaves the element.
    /// Design: docs/design/platforms/web/layout.md#children-in-order
    func setItems(
        _ items: [(view: WebDOMView, values: LayoutValues)],
        travellers: [(mount: UInt64, fadeIn: ((Motion) -> Void)?)] = []
    ) {
        let views = items.map(\.view)
        if views.count != children.count || !zip(views, children).allSatisfy({ $0 === $1 }) {
            for (index, view) in views.enumerated() { WebRelay.insert(view.node, into: node, at: index) }
        }
        // A child let go of first - a page popped - is gone from the page already, and its number may be another's.
        for gone in children where !gone.isReleased && gone.placingLayout === self
            && !items.contains(where: { $0.view === gone }) {
            WebRelay.detach(gone.node)
            gone.placingLayout = nil
        }
        children = views
        values = items.map(\.values)
        self.travellers = travellers
        for view in views { view.placingLayout = self }
        if arrangement == .grid { writeTracks() }
        placeAll()
    }

    /// Whether the children travel to their places: a stack's, a grid's, a ZStack's in their areas.
    var travels: Bool {
        switch arrangement {
        case .stack, .grid: true
        case .layers: placement == nil
        case .single: false
        }
    }

    /// Stands the child at `index` at `slot`, where the browser laid it out, or on its way there.
    func place(_ child: WebDOMView, at index: Int, slot: Rect) {
        let traveller = index < travellers.count ? travellers[index] : (mount: 0, fadeIn: nil)
        places.place(child, mount: traveller.mount, at: slot, values: values[index], fadeIn: traveller.fadeIn)
    }

    private func placeAll() {
        if travels { placing?.arrange(self) }
        let run = arrangement == .layers ? placement?.placements ?? [] : []
        let order = ZStackArithmetic.drawingOrder(of: children.count, placedBy: run)
        for (index, view) in children.enumerated() {
            if index < run.count {
                placeByRun(view, run[index])
            } else {
                place(view, values[index])
            }
            // A ZStack draws every child in its order, the placed and the unplaced alike, back to front.
            if arrangement == .layers { view.style("z-index", String(order.firstIndex(of: index) ?? index)) }
        }
    }

    /// Writes where `view` stands in this layout: its margin, its stated sizes and their bounds, and its alignment
    /// across its slot - in a grid's cell, along both axes.
    /// Design: docs/design/platforms/web/layout.md#a-childs-place
    func place(_ view: WebDOMView, _ values: LayoutValues) {
        view.drawInRun(nil, size: nil)
        for (side, length) in WebCSS.sides(values.margin) { view.style("margin-\(side)", length) }
        view.style("width", WebCSS.pixels(values.width))
        view.style("height", WebCSS.pixels(values.height))
        // A child is no larger than its slot - across a stack, in a cell, an area or a room it does not scroll in.
        let boundAcross = arrangement != .stack(.horizontal) && !scrolls.across
        let boundDown = arrangement != .stack(.vertical) && !scrolls.down
        view.style("max-width", WebCSS.most(values.maximumWidth, bound: boundAcross))
        view.style("max-height", WebCSS.most(values.maximumHeight, bound: boundDown))
        let stopsAcross = values.width != nil || values.maximumWidth != nil
        let stopsDown = values.height != nil || values.maximumHeight != nil
        let across = WebCSS.alignment(values.horizontal, stops: stopsAcross)
        let down = WebCSS.alignment(values.vertical, stops: stopsDown)
        // The least a control's look gives it is its own size, which a size or a most the tree states, a slot it
        // fills and an area it stands in win over.
        let sized = arrangement == .layers && values.area != nil
        let fillsAcross = across == "stretch" && arrangement != .stack(.horizontal)
        let fillsDown = down == "stretch" && arrangement != .stack(.vertical)
        let yieldsAcross = stopsAcross || fillsAcross || sized
        let yieldsDown = stopsDown || fillsDown || sized
        view.style("min-width", WebCSS.pixels(values.minimumWidth) ?? (yieldsAcross ? "0" : nil))
        view.style("min-height", WebCSS.pixels(values.minimumHeight) ?? (yieldsDown ? "0" : nil))
        switch arrangement {
        case .stack(let axis):
            view.style("flex", "none")
            view.style("justify-self", nil)
            view.style("align-self", axis == .vertical ? across : down)
        case .single, .grid, .layers:
            view.style("flex", nil)
            view.style("justify-self", across)
            view.style("align-self", down)
        }
        switch arrangement {
        case .grid:
            view.style("grid-row", "\(values.row + 1) / span \(max(1, values.rowSpan))")
            view.style("grid-column", "\(values.column + 1) / span \(max(1, values.columnSpan))")
        case .layers:
            placeInArea(view, values.area)
        default:
            break
        }
    }

    /// A ZStack's child in its area - in points from the room's top left, or in fractions of the room - else in the
    /// whole room, the one cell every child shares.
    private func placeInArea(_ view: WebDOMView, _ area: Area?) {
        // A run's drawn opacity gives way to the view's own, which a placing never touches.
        // Design: docs/design/platforms/web/layout.md#a-placing-run
        view.setOpacity(view.opacity)
        guard let area else {
            view.style("grid-area", "1 / 1 / 2 / 2")
            return view.style("position", "relative")
        }
        let (left, top) = (WebCSS.pixels(padding.left)!, WebCSS.pixels(padding.top)!)
        let room = "(100% - \(WebCSS.pixels(padding.left + padding.right)!))"
        let tall = "(100% - \(WebCSS.pixels(padding.top + padding.bottom)!))"
        view.style("position", "absolute")
        view.style("grid-area", nil)
        switch area {
        case .absolute(let x, let y, let width, let height):
            view.style("left", "calc(\(left) + \(WebCSS.pixels(x)!))")
            view.style("top", "calc(\(top) + \(WebCSS.pixels(y)!))")
            view.style("width", WebCSS.pixels(width))
            view.style("height", WebCSS.pixels(height))
        case .proportional(let x, let y, let width, let height):
            view.style("left", "calc(\(left) + \(room) * \(WebCSS.number(x)))")
            view.style("top", "calc(\(top) + \(tall) * \(WebCSS.number(y)))")
            view.style("width", "calc(\(room) * \(WebCSS.number(width)))")
            view.style("height", "calc(\(tall) * \(WebCSS.number(height)))")
        }
    }

    /// A child where the run puts it, drawn as it says, over the children placed before it in the run's order.
    /// Design: docs/design/platforms/web/layout.md#a-placing-run
    private func placeByRun(_ view: WebDOMView, _ placement: HostPlacement) {
        let place = placement.place
        view.style("position", "absolute")
        view.style("grid-area", nil)
        view.style("left", WebCSS.signedPixels(place.x))
        view.style("top", WebCSS.signedPixels(place.y))
        view.style("width", WebCSS.pixels(place.width))
        view.style("height", WebCSS.pixels(place.height))
        view.style("opacity", placement.drawnOpacity >= 1 ? nil : WebCSS.number(placement.drawnOpacity))
        view.drawInRun(placement.drawing, size: LayoutSize(width: place.width, height: place.height))
    }

    /// The grid's tracks: those it defines, then one share for each further one its children reach.
    private func writeTracks() {
        let rowCount = max(rows.count, values.map { $0.row + max(1, $0.rowSpan) }.max() ?? 0)
        let columnCount = max(columns.count, values.map { $0.column + max(1, $0.columnSpan) }.max() ?? 0)
        style("grid-template-rows", WebCSS.tracks(rows, count: rowCount))
        style("grid-template-columns", WebCSS.tracks(columns, count: columnCount))
    }
}
