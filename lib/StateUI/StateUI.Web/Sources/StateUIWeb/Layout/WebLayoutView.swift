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

    /// The children's views and what each one's place reads, in order: read when first wanted and kept until the
    /// children are set again, so a child a run places never reads it.
    /// Design: docs/design/platforms/web/layout.md#a-placing-run
    private(set) var children: [WebDOMView] = []
    private var readValues: [() -> LayoutValues] = []
    private var valuesRead: [LayoutValues?] = []

    /// Each child's mounted element, by number, and how it fades in as it joins: what its place travels by.
    private var travelers: [(mount: UInt64, fadeIn: ((Motion) -> Void)?)] = []

    /// Where the children travel to their places, and who reads their places on the page; nil while they stand at
    /// once wherever the browser lays them out.
    let places = TravelingPlaces()
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

    /// The room left between the children of a stack, along its axis.
    func setSpacing(_ spacing: Double) {
        style(arrangement == .stack(.vertical) ? "row-gap" : "column-gap", spacing == 0 ? nil : WebCSS.pixels(spacing))
    }

    /// Whether a row wraps, its lines from its top the room between them apart, each standing as its alignment says.
    /// Design: docs/design/platforms/web/layout.md#a-row-that-wraps
    func setLines(_ lines: StackArithmetic.Lines) {
        guard case .wrapped(let spacing, let alignment) = lines else {
            return ["flex-wrap", "align-content", "row-gap", "justify-content"].forEach { style($0, nil) }
        }
        style("flex-wrap", "wrap")
        style("align-content", "flex-start")
        style("row-gap", spacing == 0 ? nil : WebCSS.pixels(spacing))
        // Each line across the row as its alignment says; a growing child fills its line all the same.
        style("justify-content", alignment == .center ? "center" : alignment == .end ? "flex-end" : nil)
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

    /// A ZStack's areas stand from its start side, so its children stand again as it turns.
    override func setDirection(_ direction: LayoutDirection) {
        let turned = isRightToLeft != (direction == .rightToLeft)
        super.setDirection(direction)
        if turned, arrangement == .layers { placeAll() }
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
        _ items: [(view: WebDOMView, values: () -> LayoutValues)],
        travelers: [(mount: UInt64, fadeIn: ((Motion) -> Void)?)] = []
    ) {
        let views = items.map(\.view)
        if views.count != children.count || !zip(views, children).allSatisfy({ $0 === $1 }) {
            for (index, view) in views.enumerated() { WebRelay.insert(view.node, into: node, at: index) }
        }
        // A child let go of first - a page popped - is gone from the page already, and its number names nothing.
        for gone in children where !gone.isReleased && gone.placingLayout === self
            && !items.contains(where: { $0.view === gone }) {
            WebRelay.detach(gone.node)
            gone.placingLayout = nil
        }
        children = views
        readValues = items.map(\.values)
        valuesRead = Array(repeating: nil, count: items.count)
        self.travelers = travelers
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
        let traveler = index < travelers.count ? travelers[index] : (mount: 0, fadeIn: nil)
        places.place(
            child, mount: traveler.mount, at: slot, values: values(at: index),
            natural: { child.heldWords ?? WebRelay.natural(of: child.node) }, fadeIn: traveler.fadeIn)
    }

    private func placeAll() {
        if travels { placing?.arrange(self) }
        let run = arrangement == .layers ? placement?.placements ?? [] : []
        // Children sharing room draw back to front - a grid's in their order, a ZStack's in its run's, the placed
        // and the unplaced alike - each child's place in that order worked out once; else a child standing out of
        // the page's flow, a shape, rises over the later ones.
        var drawnAt = Array(children.indices)
        if arrangement == .layers {
            for (place, index) in ZStackArithmetic.drawingOrder(of: children.count, placedBy: run).enumerated() {
                drawnAt[index] = place
            }
        }
        for (index, view) in children.enumerated() {
            if index < run.count, let placement {
                placeByRun(view, placement, at: index)
            } else {
                place(view, values(at: index))
            }
            if arrangement == .layers || arrangement == .grid { view.style("z-index", String(drawnAt[index])) }
        }
    }

    /// What the child at `index` states of its own place, read once since the children were set.
    private func values(at index: Int) -> LayoutValues {
        if let read = valuesRead[index] { return read }
        let read = readValues[index]()
        valuesRead[index] = read
        return read
    }

    /// Writes where `view` stands in this layout: its margin, its stated sizes and their bounds, and its alignment
    /// across its slot - in a grid's cell, along both axes.
    /// Design: docs/design/platforms/web/layout.md#a-childs-place
    func place(_ view: WebDOMView, _ values: LayoutValues) {
        view.placedByRun = nil
        if view.placedFromRight {
            view.style("right", nil)
            view.placedFromRight = false
        }
        view.drawInRun(nil, size: nil)
        view.style("will-change", nil)
        for (side, length) in WebCSS.sides(values.margin, margin: true) { view.style("margin-\(side)", length) }
        // A child is no larger than its slot - across a stack, in a cell, an area or a room it does not scroll in.
        let area = arrangement == .layers ? values.area.map { box(of: $0, margin: values.margin) } : nil
        let boundAcross = arrangement != .stack(.horizontal) && !scrolls.across ? area?.width ?? "100%" : nil
        let boundDown = arrangement != .stack(.vertical) && !scrolls.down ? area?.height ?? "100%" : nil
        view.style("max-width", WebCSS.most(values.maximumWidth, within: boundAcross))
        view.style("max-height", WebCSS.most(values.maximumHeight, within: boundDown))
        // A filling child in an area - where the browser stretches a control no narrower than its own size - takes
        // the area's length, which its most bounds, in its middle.
        // Design: docs/design/platforms/web/layout.md#a-childs-area
        let fillsItsArea = (
            across: values.horizontal == 3 && values.width == nil, down: values.vertical == 3 && values.height == nil)
        view.style("width", WebCSS.pixels(values.width) ?? (fillsItsArea.across ? area?.width : nil))
        view.style("height", WebCSS.pixels(values.height) ?? (fillsItsArea.down ? area?.height : nil))
        let stopsAcross = values.width != nil || values.maximumWidth != nil
        let stopsDown = values.height != nil || values.maximumHeight != nil
        let across = WebCSS.alignment(values.horizontal, stops: stopsAcross)
        let down = WebCSS.alignment(values.vertical, stops: stopsDown)
        // The least a control's look gives it is its own size, which a size or a most the tree states, a slot it
        // fills and an area it stands in win over.
        let sized = arrangement == .layers && values.area != nil
        let fillsAcross = across == "stretch" && arrangement != .stack(.horizontal)
        let fillsDown = down == "stretch" && arrangement != .stack(.vertical)
        // A row short of room takes it from its words: the browser shrinks them alike, by their natural widths.
        let wordsInARow = arrangement == .stack(.horizontal) && values.yieldsInARow
        let yieldsAcross = stopsAcross || fillsAcross || sized || wordsInARow
        let yieldsDown = stopsDown || fillsDown || sized
        // In an area its least gives way to the area's length, as the host layer bounds it by the room it has.
        let least = { (least: Double?, yields: Bool, bound: String?) -> String? in
            guard let stated = WebCSS.pixels(least) else { return yields ? "0" : nil }
            return bound.map { "min(\(stated), \($0))" } ?? stated
        }
        view.style("min-width", least(values.minimumWidth, yieldsAcross, area?.width))
        view.style("min-height", least(values.minimumHeight, yieldsDown, area?.height))
        switch arrangement {
        case .stack(let axis):
            // A space takes an equal share of the room its siblings leave.
            view.style("flex", values.grows(along: axis) ? "1 1 0" : wordsInARow ? "0 1 auto" : "none")
            view.style("justify-self", nil)
            view.style("align-self", axis == .vertical ? across : down)
        case .single, .grid, .layers:
            view.style("flex", nil)
            view.style("justify-self", across)
            // A first baseline is a row's: anywhere else, the near edge.
            view.style("align-self", values.vertical == Alignment.firstBaseline.rawValue ? "start" : down)
        }
        switch arrangement {
        case .grid:
            // The cell the host layer gives every grid (`GridArithmetic.cell`), its lines counted from one.
            let cell = GridArithmetic.cell(of: values)
            view.style("grid-row", "\(cell.row + 1) / span \(cell.rowSpan)")
            view.style("grid-column", "\(cell.column + 1) / span \(cell.columnSpan)")
        case .layers:
            placeInArea(view, area)
        default:
            break
        }
    }

    /// The box a ZStack's child stands in: its area's edges as CSS insets from the room's - its start one from the
    /// room's start side, below nothing too - and how wide and tall the child may be within its margin.
    struct AreaBox {
        let start, top, end, bottom: String
        let width, height: String
    }

    /// The box `area` names within the padding - in points from the room's start corner, or in fractions of the room.
    /// Design: docs/design/platforms/web/layout.md#a-childs-area
    private func box(of area: Area, margin: Insets) -> AreaBox {
        let (start, top) = (padding.start, padding.top)
        let n: (Double) -> String = WebCSS.signedPixels
        switch area {
        case .absolute(let area):
            let (width, height) = (max(0, area.width), max(0, area.height))
            return AreaBox(
                start: n(start + area.x), top: n(top + area.y),
                end: "calc(100% - \(n(start + area.x + width)))", bottom: "calc(100% - \(n(top + area.y + height)))",
                width: WebCSS.pixels(width - margin.start - margin.end)!,
                height: WebCSS.pixels(height - margin.top - margin.bottom)!)
        case .proportional(let area):
            let room = "(100% - \(n(padding.start + padding.end)))"
            let tall = "(100% - \(n(padding.top + padding.bottom)))"
            let (width, height) = (max(0, area.width), max(0, area.height))
            let f: (Double) -> String = WebCSS.number
            return AreaBox(
                start: "calc(\(n(start)) + \(room) * \(f(area.x)))", top: "calc(\(n(top)) + \(tall) * \(f(area.y)))",
                end: "calc(100% - \(n(start)) - \(room) * \(f(area.x + width)))",
                bottom: "calc(100% - \(n(top)) - \(tall) * \(f(area.y + height)))",
                width: "max(0px, calc(\(room) * \(f(width)) - \(n(margin.start + margin.end))))",
                height: "max(0px, calc(\(tall) * \(f(height)) - \(n(margin.top + margin.bottom))))")
        }
    }

    /// A ZStack's child in its area's box, where it stands by its own size and alignments as in any slot - mirrored
    /// right to left, its start edge the room's right - else in the whole room, the one cell every child shares.
    /// Design: docs/design/platforms/web/layout.md#a-childs-area
    private func placeInArea(_ view: WebDOMView, _ area: AreaBox?) {
        // A run's drawn opacity gives way to the view's own, which a placing never touches.
        // Design: docs/design/platforms/web/layout.md#a-placing-run
        view.setOpacity(view.opacity)
        guard let area else {
            view.style("grid-area", "1 / 1 / 2 / 2")
            for side in ["left", "top", "right", "bottom"] { view.style(side, nil) }
            return view.style("position", "relative")
        }
        view.style("position", "absolute")
        view.style("grid-area", nil)
        let (start, end) = isRightToLeft ? ("right", "left") : ("left", "right")
        view.style(start, area.start)
        view.style("top", area.top)
        view.style(end, area.end)
        view.style("bottom", area.bottom)
    }

    /// A child where the run puts it, drawn as it says, over the children placed before it in the run's order.
    /// Design: docs/design/platforms/web/layout.md#a-placing-run
    private func placeByRun(_ view: WebDOMView, _ run: HostPlacementRun, at index: Int) {
        // A run moves its views every frame: what has not moved is not written again, not even as words.
        // Design: docs/design/platforms/web/layout.md#a-placing-run
        let (placement, place, last) = (run.placements[index], run.writtenPlace(of: index), view.placedByRun)
        view.placedByRun = placement
        if last == nil {
            view.style("position", "absolute")
            view.style("grid-area", nil)
            // The place is a move drawn over the layout's corner, which the browser composes each frame without
            // laying the page out again, and the view its own layer to move.
            view.style("top", "0px")
            view.style("bottom", nil)
            view.style("will-change", "transform")
            // The run's size, whatever the room's: a slot's bound would squash a card a short room scales down.
            view.style("max-width", "none")
            view.style("max-height", "none")
        }
        // Right to left the view stands at the right corner and moves left: the mirror of its place, the room unread.
        let fromRight = run.direction == .rightToLeft
        if last == nil || view.placedFromRight != fromRight {
            view.style(fromRight ? "right" : "left", "0px")
            view.style(fromRight ? "left" : "right", nil)
            view.placedFromRight = fromRight
        }
        if last?.bounds.width != placement.bounds.width || last?.bounds.height != placement.bounds.height {
            view.style("width", WebCSS.pixels(place.width))
            view.style("height", WebCSS.pixels(place.height))
        }
        view.style("opacity", placement.drawnOpacity >= 1 ? nil : WebCSS.number(placement.drawnOpacity))
        view.drawInRun(
            run.drawing(of: index), size: LayoutSize(width: place.width, height: place.height),
            at: Point(fromRight ? -place.x : place.x, place.y))
        (view as? WebLayoutView)?.setShadeOpacity(placement.drawnShade)
    }

    /// Draws a placed card's shade - its second layer, over its face - as opaque as the run says.
    /// Design: docs/design/platforms/web/layout.md#a-placing-run
    func setShadeOpacity(_ opacity: Double) {
        guard arrangement == .grid, children.count > 1 else { return }
        children[1].setOpacity(opacity)
    }

    /// The grid's tracks as the host layer gives them (`GridArithmetic.tracks`): those it defines, then one share for
    /// each further one its children reach.
    private func writeTracks() {
        let tracks = GridArithmetic.tracks(reaching: readValues.indices.map(values(at:)), rows: rows, columns: columns)
        style("grid-template-rows", WebCSS.tracks(tracks.rows))
        style("grid-template-columns", WebCSS.tracks(tracks.columns))
    }
}
