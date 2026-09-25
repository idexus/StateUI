// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// One of the six shapes: a WinUI Path, its geometry drawn for the room it is given, filled and outlined.
/// Design: docs/design/platforms/winui/drawing.md#the-shapes
@MainActor
final class WinUIPathView: WinUIView {
    /// What the shape draws: a rectangle, its corners clockwise from the top left; an ellipse; or a geometry of
    /// its own, as flat commands, placed by its aspect and moved by its transform (`ShapeArithmetic.placement`).
    enum Geometry: Equatable {
        case rectangle([Double])
        case ellipse
        case authored([Double], evenOdd: Bool, aspect: Aspect, transform: [Double]?)
    }

    private var geometry = Geometry.rectangle([0, 0, 0, 0])
    private var strokeWidth = 1.0

    /// Where a geometry of the shape's own stands before it is placed, as WinUI measures it.
    private var bounds = Rect(x: 0, y: 0, width: 0, height: 0)

    /// The geometry and the room it was last drawn for.
    private var drawn: (geometry: Geometry, width: Double, height: Double, inset: Double)?

    init() {
        super.init { _ in stateui_winui_path_make() }
    }

    /// Paints the shape.
    func paint(
        fill: WinUIBrush, stroke: WinUIBrush, width: Double, dashes: [Double], dashOffset: Double, cap: LineCap,
        join: LineJoin, miter: Double
    ) {
        strokeWidth = ShapeArithmetic.strokeWidth(width)
        fill.withRelayBrush { fill in
            stroke.withRelayBrush { stroke in
                stateui_winui_path_paint(
                    handle, fill, stroke, strokeWidth, dashes, Int32(dashes.count), dashOffset, cap.rawValue, join.rawValue,
                    miter)
            }
        }
        if let placed { draw(in: placed) }
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
        super.layout(place)
        draw(in: place)
    }

    /// Hands WinUI the geometry for `room`, again only where the room or the geometry changed.
    private func draw(in room: Rect) {
        let inset = strokeWidth / 2
        if let drawn, drawn.geometry == geometry, drawn.width == room.width, drawn.height == room.height,
           drawn.inset == inset { return }

        drawn = (geometry, room.width, room.height, inset)
        switch geometry {
        case .rectangle(let radii):
            stateui_winui_path_draw(handle, 0, radii, nil, 0, false, nil, room.width, room.height, inset)
        case .ellipse:
            stateui_winui_path_draw(handle, 1, nil, nil, 0, false, nil, room.width, room.height, inset)
        case .authored(let commands, let evenOdd, let aspect, let transform):
            let placement = ShapeArithmetic.placement(
                of: bounds, in: LayoutSize(width: room.width, height: room.height), aspect: aspect,
                transform: transform)
            stateui_winui_path_draw(
                handle, 2, nil, commands, Int32(commands.count), evenOdd, placement, room.width, room.height, inset)
        }
    }
}
