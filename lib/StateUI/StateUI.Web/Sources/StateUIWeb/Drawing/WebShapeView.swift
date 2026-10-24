// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A shape: a box taking no room of its own, as a shape has no size of its own, and over it an `<svg>` holding one
/// path, drawn again as its room changes - a rectangle and an ellipse filling the room, half their outline in from its edges, and a geometry of the shape's own placed in it by the host layer's
/// arithmetic - filled and outlined by its brushes, the outline never scaled with it.
/// Design: docs/design/platforms/web/drawing.md#a-shape
@MainActor
final class WebShapeView: WebDOMView {
    /// What the shape draws.
    enum Geometry {
        case rectangle([Double], transform: [Double]?)
        case ellipse(transform: [Double]?)
        case authored([Double], evenOdd: Bool, aspect: ContentMode, transform: [Double]?)
    }

    private let surface = WebDOMView(vector: "svg")
    private let path = WebDOMView(vector: "path")
    private let brushes = WebDOMView(vector: "defs")
    private var shown: [WebDOMView] = []

    /// The blur the figure is made of - a box of the page's blur under its color - cut to the figure by a clip path of
    /// its own geometry; nil where the fill is a paint.
    /// Design: docs/design/platforms/web/drawing.md#a-figure-made-of-a-material
    private var backdrop: WebDOMView?
    private let clip = WebDOMView(vector: "clipPath")
    private let clipPath = WebDOMView(vector: "path")
    private var material = HostMaterial(nil)

    private var geometry: Geometry?
    private var fill: HostValue?
    private var stroke: HostValue?
    private var lineWidth = 1.0

    init() {
        super.init(tag: "div")
        attribute("class", "stateui-shape")
        WebRelay.insert(surface.node, into: node, at: 0)
        WebRelay.insert(brushes.node, into: surface.node, at: 0)
        WebRelay.insert(path.node, into: surface.node, at: 1)
        followSize { [weak self] in self?.redraw() }
    }

    /// How the shape fills and outlines its path.
    func paint(
        fill: HostValue?, stroke: HostValue?, width: Double, dashes: [Double], dashOffset: Double,
        cap: LineCap, join: LineJoin, miter: Double
    ) {
        material = HostMaterial(fill)
        // A blur's tint lies in the backdrop's color, over the blur.
        (self.fill, self.stroke, lineWidth) = (
            material.blur == nil ? material.paint : nil, stroke, ShapeArithmetic.lineWidth(width))
        let lengths = ShapeArithmetic.dashLengths(dashes, lineWidth: lineWidth)
        path.attribute("stroke-width", WebCSS.number(lineWidth))
        path.attribute("stroke-linecap", cap == .round ? "round" : cap == .square ? "square" : "butt")
        path.attribute("stroke-linejoin", join == .round ? "round" : join == .bevel ? "bevel" : "miter")
        path.attribute("stroke-miterlimit", WebCSS.number(miter))
        let dashed = lengths.contains { $0 > 0 }
        path.attribute("stroke-dasharray", dashed ? lengths.map(WebCSS.number).joined(separator: " ") : nil)
        path.attribute("stroke-dashoffset", dashOffset == 0 ? nil : WebCSS.number(dashOffset * lineWidth))
        path.attribute("vector-effect", "non-scaling-stroke")
        redraw()
    }

    func draw(_ geometry: Geometry) {
        self.geometry = geometry
        redraw()
    }

    /// The path for the room the shape stands in now, and its brushes over that room.
    private func redraw() {
        guard let geometry else { return }
        let width = WebRelay.number(of: node, "clientWidth")
        let height = WebRelay.number(of: node, "clientHeight")
        let outlined = stroke != nil && lineWidth > 0
        let inset = outlined ? lineWidth / 2 : 0
        let room = Rect(x: inset, y: inset, width: max(0, width - inset * 2), height: max(0, height - inset * 2))
        // The path's own transform, which a gradient over the room undoes: it lies in the path's units.
        let placed: [Double]?
        let rule: String?
        let drawn: String
        switch geometry {
        case .rectangle(let radii, let transform):
            drawn = WebVector.rounded(room, radii: radii)
            path.attribute("d", drawn)
            (rule, placed) = (nil, transform)
        case .ellipse(let transform):
            drawn = WebVector.ellipse(in: room)
            path.attribute("d", drawn)
            (rule, placed) = (nil, transform)
        case .authored(let commands, let evenOdd, let aspect, let transform):
            drawn = WebVector.path(commands)
            path.attribute("d", drawn)
            rule = evenOdd ? "evenodd" : "nonzero"
            placed = ShapeArithmetic.placement(
                of: WebRelay.shapeBounds(of: path.node), in: LayoutSize(width: width, height: height),
                aspect: aspect, transform: transform)
        }
        path.attribute("fill-rule", rule)
        path.attribute("transform", placed.flatMap(WebVector.matrix))
        showBackdrop(drawn, rule: rule, transform: placed.flatMap(WebVector.matrix), size: LayoutSize(width: width, height: height))
        let painted = Rect(x: -lineWidth, y: -lineWidth, width: width + lineWidth * 2, height: height + lineWidth * 2)
        let undone = placed.flatMap(WebVector.inverse).flatMap(WebVector.matrix)
        for gone in shown { gone.release() }
        shown = []
        path.attribute("fill", brush(fill, "fill", over: painted, undoing: undone))
        path.attribute("stroke", outlined ? brush(stroke, "stroke", over: painted, undoing: undone) : "none")
    }

    /// Shows the fill's blur under the figure, cut to the path as it is drawn now; takes it away where the fill is a
    /// paint.
    private func showBackdrop(_ drawn: String, rule: String?, transform: String?, size: LayoutSize) {
        guard material.blur != nil else {
            backdrop?.release()
            backdrop = nil
            return
        }
        let shown = backdrop ?? WebDOMView(tag: "div")
        if backdrop == nil {
            shown.attribute("class", "stateui-shape-backdrop")
            WebRelay.insert(shown.node, into: node, at: 0)
            clip.attribute("id", "stateui-\(serial)-clip")
            clip.attribute("clipPathUnits", "userSpaceOnUse")
            WebRelay.insert(clip.node, into: surface.node, at: 0)
            WebRelay.insert(clipPath.node, into: clip.node, at: 0)
            backdrop = shown
        }
        clipPath.attribute("d", drawn)
        clipPath.attribute("clip-rule", rule)
        clipPath.attribute("transform", transform)
        for (name, value) in WebBox(fill: material.paint, material: material).styles(size: size) {
            shown.style(name, value)
        }
        shown.style("clip-path", "url(#stateui-\(serial)-clip)")
    }

    /// A brush as SVG paints it over `painted`: a color, or a gradient of its own, its geometry in that room.
    private func brush(_ value: HostValue?, _ role: String, over painted: Rect, undoing placed: String?) -> String {
        guard let gradient = WebVector.gradient(HostBrush(value), over: painted, id: "stateui-\(serial)-\(role)") else {
            return WebCSS.color(HostBrush(value).firstColor) ?? "none"
        }
        brushes.attribute("data-brushes", "")
        let made = WebDOMView(vector: gradient.tag)
        for (name, written) in gradient.attributes { made.attribute(name, written) }
        made.attribute("gradientTransform", placed)
        for (index, stop) in gradient.stops.enumerated() {
            let element = WebDOMView(vector: "stop")
            element.attribute("offset", WebCSS.number(stop.offset))
            element.attribute("stop-color", WebCSS.color(stop.color) ?? "transparent")
            WebRelay.insert(element.node, into: made.node, at: index)
            shown.append(element)
        }
        WebRelay.insert(made.node, into: brushes.node, at: shown.count)
        shown.append(made)
        return "url(#\(gradient.id))"
    }

    override func release() {
        backdrop?.release()
        clipPath.release()
        clip.release()
        for each in shown { each.release() }
        path.release()
        brushes.release()
        surface.release()
        super.release()
    }
}
