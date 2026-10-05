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
        WebRelay.observeSize(node, WebRelay.listener { [weak self] in self?.redraw() })
    }

    /// How the shape fills and outlines its path.
    func paint(
        fill: HostValue?, stroke: HostValue?, width: Double, dashes: [Double], dashOffset: Double,
        cap: LineCap, join: LineJoin, miter: Double
    ) {
        (self.fill, self.stroke, lineWidth) = (fill, stroke, ShapeArithmetic.lineWidth(width))
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
        switch geometry {
        case .rectangle(let radii, let transform):
            path.attribute("d", WebVector.rounded(room, radii: radii))
            path.attribute("fill-rule", nil)
            path.attribute("transform", transform.flatMap(WebVector.matrix))
        case .ellipse(let transform):
            path.attribute("d", WebVector.ellipse(in: room))
            path.attribute("fill-rule", nil)
            path.attribute("transform", transform.flatMap(WebVector.matrix))
        case .authored(let commands, let evenOdd, let aspect, let transform):
            path.attribute("d", WebVector.path(commands))
            path.attribute("fill-rule", evenOdd ? "evenodd" : "nonzero")
            let placement = ShapeArithmetic.placement(
                of: WebRelay.shapeBounds(of: path.node), in: LayoutSize(width: width, height: height),
                aspect: aspect, transform: transform)
            path.attribute("transform", WebVector.matrix(placement))
        }
        let painted = Rect(x: -lineWidth, y: -lineWidth, width: width + lineWidth * 2, height: height + lineWidth * 2)
        for gone in shown { gone.detach() }
        shown = []
        path.attribute("fill", brush(fill, "fill", over: painted))
        path.attribute("stroke", outlined ? brush(stroke, "stroke", over: painted) : "none")
    }

    /// A brush as SVG paints it over `painted`: a colour, or a gradient of its own, its geometry in that room.
    private func brush(_ value: HostValue?, _ role: String, over painted: Rect) -> String {
        guard let gradient = WebVector.gradient(HostBrush(value), over: painted, id: "stateui-\(serial)-\(role)") else {
            return WebCSS.color(HostBrush(value).firstColor) ?? "none"
        }
        brushes.attribute("data-brushes", "")
        let made = WebDOMView(vector: gradient.tag)
        for (name, written) in gradient.attributes { made.attribute(name, written) }
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

    override func detach() {
        for each in shown { each.detach() }
        path.detach()
        brushes.detach()
        surface.detach()
        super.detach()
    }
}
