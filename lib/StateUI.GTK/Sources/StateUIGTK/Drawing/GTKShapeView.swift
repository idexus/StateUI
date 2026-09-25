// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// One of the six shapes: a panel drawing its geometry with GSK's own paths for the room its layout gives it, filled
/// and outlined by their brushes.
/// Design: docs/design/platforms/gtk/drawing.md#the-shapes
@MainActor
final class GTKShapeView: GTKPanelView {
    /// What the shape draws: a rectangle, its corners clockwise from the top left; an ellipse; or a geometry of its
    /// own, as flat commands - 0 move, 1 line, 2 cubic, 3 quadratic, 4 close - placed by its aspect and moved by
    /// its transform.
    enum Geometry: Equatable {
        case rectangle([Double])
        case ellipse
        case authored([Double], evenOdd: Bool, aspect: Aspect, transform: [Double]?)
    }

    private var geometry = Geometry.rectangle([0, 0, 0, 0])
    private var fill = GTKBrush.none
    private var stroke = GTKBrush.none
    private var strokeWidth = 1.0
    private var dashes: [Double] = []
    private var dashOffset = 0.0
    private var cap = LineCap.flat
    private var join = LineJoin.miter
    private var miter = 10.0

    /// How the shape is filled and outlined: dashes, gaps and their offset in outline widths.
    func paint(
        fill: GTKBrush, stroke: GTKBrush, width: Double, dashes: [Double], dashOffset: Double, cap: LineCap,
        join: LineJoin, miter: Double
    ) {
        (self.fill, self.stroke, strokeWidth) = (fill, stroke, width.isFinite ? max(0, width) : 0)
        (self.dashes, self.dashOffset, self.cap, self.join, self.miter) = (dashes, dashOffset, cap, join, miter)
        gtk_widget_queue_draw(widget)
    }

    /// What the shape draws, for whatever room it is given.
    func draw(_ geometry: Geometry) {
        guard geometry != self.geometry else { return }
        self.geometry = geometry
        gtk_widget_queue_draw(widget)
    }

    /// A shape has no size of its own: it takes the room its layout gives it.
    override func measure(across: Bool, forSize: Int32) -> Double {
        0
    }

    override func draw(_ snapshot: OpaquePointer, width: Double, height: Double) {
        let outlined = stroke != .none && strokeWidth > 0
        guard width > 0 || height > 0, let (path, evenOdd) = path(width: width, height: height, outlined: outlined)
        else { return }
        defer { gsk_path_unref(path) }

        if fill != .none {
            gtk_snapshot_push_fill(snapshot, path, evenOdd ? GSK_FILL_RULE_EVEN_ODD : GSK_FILL_RULE_WINDING)
            fill.paint(snapshot, Self.rect(-strokeWidth, -strokeWidth, width + strokeWidth * 2, height + strokeWidth * 2))
            gtk_snapshot_pop(snapshot)
        }
        guard outlined else { return }

        let outline = gsk_stroke_new(Float(strokeWidth))
        defer { gsk_stroke_free(outline) }
        gsk_stroke_set_line_cap(outline, cap == .round ? GSK_LINE_CAP_ROUND : cap == .square ? GSK_LINE_CAP_SQUARE : GSK_LINE_CAP_BUTT)
        gsk_stroke_set_line_join(outline, join == .round ? GSK_LINE_JOIN_ROUND : join == .bevel ? GSK_LINE_JOIN_BEVEL : GSK_LINE_JOIN_MITER)
        gsk_stroke_set_miter_limit(outline, Float(miter))
        // StateUI measures dashes and gaps in outline widths, GSK in lengths.
        let lengths = dashes.map { Float(max(0, $0) * strokeWidth) }
        if lengths.contains(where: { $0 > 0 }) {
            gsk_stroke_set_dash(outline, lengths, gsize(lengths.count))
            gsk_stroke_set_dash_offset(outline, Float(dashOffset * strokeWidth))
        }
        gtk_snapshot_push_stroke(snapshot, path, outline)
        stroke.paint(snapshot, Self.rect(-strokeWidth, -strokeWidth, width + strokeWidth * 2, height + strokeWidth * 2))
        gtk_snapshot_pop(snapshot)
    }

    /// The path for a room `width` by `height`: a rectangle and an ellipse fill it, half their outline in from its
    /// edges; a geometry of the shape's own is placed in it. Whether it fills by the even-odd rule.
    private func path(width: Double, height: Double, outlined: Bool) -> (OpaquePointer, Bool)? {
        let builder = gsk_path_builder_new()!
        let inset = outlined ? strokeWidth / 2 : 0
        let room = Self.rect(inset, inset, max(0, width - inset * 2), max(0, height - inset * 2))
        switch geometry {
        case .rectangle(let radii):
            let limit = min(room.size.width, room.size.height) / 2
            let corners = [radii[0], radii[1], radii[2], radii[3]].map { radius in
                let kept = min(Float(radius.isFinite ? max(0, radius) : 0), limit)
                return graphene_size_t(width: kept, height: kept)
            }
            var outline = GTKOutline.rounded(room, corners: corners)
            gsk_path_builder_add_rounded_rect(builder, &outline)
            return (gsk_path_builder_free_to_path(builder), false)
        case .ellipse:
            let corner = graphene_size_t(width: room.size.width / 2, height: room.size.height / 2)
            var outline = GTKOutline.rounded(room, corners: [corner, corner, corner, corner])
            gsk_path_builder_add_rounded_rect(builder, &outline)
            return (gsk_path_builder_free_to_path(builder), false)
        case .authored(let commands, let evenOdd, let aspect, let transform):
            gsk_path_builder_unref(builder)
            let own = Self.build(commands, moved: [1, 0, 0, 1, 0, 0])
            var bounds = graphene_rect_t()
            let known = gsk_path_get_bounds(own, &bounds) != 0
            gsk_path_unref(own)
            guard known else { return nil }
            let placement = ShapeArithmetic.placement(
                of: Rect(
                    x: Double(bounds.origin.x), y: Double(bounds.origin.y),
                    width: Double(bounds.size.width), height: Double(bounds.size.height)),
                in: LayoutSize(width: width, height: height), aspect: aspect, transform: transform)
            return (Self.build(commands, moved: placement), evenOdd)
        }
    }

    /// The path the flat commands draw, every point moved by the affine `moved`.
    private static func build(_ commands: [Double], moved: [Double]) -> OpaquePointer {
        let builder = gsk_path_builder_new()!
        func point(_ x: Double, _ y: Double) -> (Float, Float) {
            (Float(moved[0] * x + moved[2] * y + moved[4]), Float(moved[1] * x + moved[3] * y + moved[5]))
        }
        var index = 0
        while index < commands.count {
            let op = Int(commands[index])
            index += 1
            let need = op == 0 || op == 1 ? 2 : op == 2 ? 6 : op == 3 ? 4 : 0
            guard index + need <= commands.count else { break }
            let p = Array(commands[index..<index + need])
            index += need
            switch op {
            case 0:
                let (x, y) = point(p[0], p[1])
                gsk_path_builder_move_to(builder, x, y)
            case 1:
                let (x, y) = point(p[0], p[1])
                gsk_path_builder_line_to(builder, x, y)
            case 2:
                let (x1, y1) = point(p[0], p[1])
                let (x2, y2) = point(p[2], p[3])
                let (x3, y3) = point(p[4], p[5])
                gsk_path_builder_cubic_to(builder, x1, y1, x2, y2, x3, y3)
            case 3:
                let (x1, y1) = point(p[0], p[1])
                let (x2, y2) = point(p[2], p[3])
                gsk_path_builder_quad_to(builder, x1, y1, x2, y2)
            case 4:
                gsk_path_builder_close(builder)
            default:
                break
            }
        }
        return gsk_path_builder_free_to_path(builder)
    }

    private static func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> graphene_rect_t {
        graphene_rect_t(
            origin: graphene_point_t(x: Float(x), y: Float(y)),
            size: graphene_size_t(width: Float(width), height: Float(height)))
    }
}
