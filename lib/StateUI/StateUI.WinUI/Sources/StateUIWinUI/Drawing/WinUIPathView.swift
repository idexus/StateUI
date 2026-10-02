// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// One of the six shapes: a WinUI Path, its geometry drawn for the room it is given, filled and outlined.
/// Design: docs/design/platforms/winui/drawing.md#the-shapes
@MainActor
final class WinUIPathView: WinUIView {
    /// What the shape draws: a rectangle, its corners clockwise from the top left, or an ellipse, each filling its
    /// room and moved by its transform; or a geometry of its own, as flat commands, placed by its aspect and moved
    /// by its transform (`ShapeArithmetic.placement`).
    enum Geometry: Equatable {
        case rectangle([Double], transform: [Double]?)
        case ellipse(transform: [Double]?)
        case authored([Double], evenOdd: Bool, aspect: Aspect, transform: [Double]?)
    }

    private var geometry = Geometry.rectangle([0, 0, 0, 0], transform: nil)
    private var lineWidth = 1.0

    /// The outline drawn, which the figure is inset by half of; none without a colour.
    private var outlineWidth = 0.0

    /// Where a geometry of the shape's own stands before it is placed, as WinUI measures it.
    private var bounds = Rect(x: 0, y: 0, width: 0, height: 0)

    /// The geometry and the room it was last drawn for.
    private var drawn: (geometry: Geometry, width: Double, height: Double, inset: Double)?

    /// How the figure is painted, and the size of the figure WinUI maps its brushes over.
    private var painting: (fill: WinUIBrush, stroke: WinUIBrush, dashes: [Double], dashOffset: Double,
                           cap: LineCap, join: LineJoin, miter: Double)?
    private var figure = LayoutSize(width: 0, height: 0)

    init() {
        super.init { number in stateui_winui_path_make(number) }
    }

    /// Paints the shape: its outline `width` wide - WinUI holding the width whatever it draws - and its figure
    /// inset by half of `outline`, the outline drawn: none without a colour.
    func paint(
        fill: WinUIBrush, stroke: WinUIBrush, width: Double, outline: Double, dashes: [Double], dashOffset: Double,
        cap: LineCap, join: LineJoin, miter: Double
    ) {
        lineWidth = ShapeArithmetic.lineWidth(width)
        outlineWidth = ShapeArithmetic.lineWidth(outline)
        painting = (fill, stroke, dashes, dashOffset, cap, join, miter)
        sendPainting()
        if let placed { draw(in: placed) }
    }

    /// Hands WinUI the painting, its brushes over the figure's box: WinUI maps a shape's brush over its geometry.
    /// Design: docs/design/platforms/winui/drawing.md#a-box-and-its-brush
    private func sendPainting() {
        guard let painting else { return }
        painting.fill.withRelayBrush(over: figure) { fill in
            painting.stroke.withRelayBrush(over: figure) { stroke in
                stateui_winui_path_paint(
                    handle, fill, stroke, lineWidth, painting.dashes, Int32(painting.dashes.count),
                    painting.dashOffset, painting.cap.rawValue, painting.join.rawValue, painting.miter)
            }
        }
    }

    /// The figure's box is `size` now: brushes that follow it are painted again.
    private func standFigure(_ size: LayoutSize) {
        guard size != figure else { return }
        figure = size
        if let painting, painting.fill.followsSize || painting.stroke.followsSize { sendPainting() }
    }

    /// Draws `geometry`, now and whenever the room changes.
    func draw(_ geometry: Geometry) {
        if case .authored(let commands, _, _, _) = geometry, geometry != self.geometry {
            var read = [0.0, 0.0, 0.0, 0.0]
            stateui_winui_path_bounds(commands, Int32(commands.count), &read)
            bounds = Rect(x: read[0], y: read[1], width: read[2], height: read[3])
        }
        self.geometry = geometry
        if let placed { draw(in: placed) }
    }

    /// A shape has no size of its own: it takes the room its layout gives it, and asks WinUI for none.
    override func measure(width: Double?, height: Double?) -> LayoutSize {
        _ = super.measure(width: 0, height: 0)
        return LayoutSize(width: 0, height: 0)
    }

    override func layout(_ place: Rect) {
        draw(in: place)
        super.layout(place)
    }

    /// Runs `draw` with a transform's six numbers as WinUI's matrix takes them; with none where there is none, or
    /// where it is not six finite numbers.
    private static func moving(by transform: [Double]?, _ draw: (UnsafePointer<Double>?) -> Void) {
        guard let transform, transform.count == 6, transform.allSatisfy(\.isFinite) else { return draw(nil) }
        transform.withUnsafeBufferPointer { draw($0.baseAddress) }
    }

    /// Hands WinUI the geometry for `room`, again only where the room or the geometry changed.
    private func draw(in room: Rect) {
        let inset = outlineWidth / 2
        if let drawn, drawn.geometry == geometry, drawn.width == room.width, drawn.height == room.height,
           drawn.inset == inset { return }

        drawn = (geometry, room.width, room.height, inset)
        let filled = LayoutSize(width: max(room.width - 2 * inset, 0), height: max(room.height - 2 * inset, 0))
        switch geometry {
        case .rectangle(let radii, let transform):
            Self.moving(by: transform) { moved in
                stateui_winui_path_draw(handle, 0, radii, nil, 0, false, moved, room.width, room.height, inset)
            }
            standFigure(filled)
        case .ellipse(let transform):
            Self.moving(by: transform) { moved in
                stateui_winui_path_draw(handle, 1, nil, nil, 0, false, moved, room.width, room.height, inset)
            }
            standFigure(filled)
        case .authored(let commands, let evenOdd, let aspect, let transform):
            let placement = ShapeArithmetic.placement(
                of: bounds, in: LayoutSize(width: room.width, height: room.height), aspect: aspect,
                transform: transform)
            stateui_winui_path_draw(
                handle, 2, nil, commands, Int32(commands.count), evenOdd, placement, room.width, room.height, inset)
            standFigure(LayoutSize(
                width: bounds.width * (placement[0] * placement[0] + placement[1] * placement[1]).squareRoot(),
                height: bounds.height * (placement[2] * placement[2] + placement[3] * placement[3]).squareRoot()))
        }
    }
}
