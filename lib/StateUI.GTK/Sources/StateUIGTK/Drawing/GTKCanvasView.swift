// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A Canvas: a panel replaying its drawing in order on GTK's snapshot - the instructions and the pen the host layer
/// reads (`CanvasInstruction`, `CanvasPen`), its arcs the host layer's curves - within its own room; a press, its
/// drag and its release told where they are.
/// Design: docs/design/platforms/gtk/drawing.md#a-canvas
@MainActor
final class GTKCanvasView: GTKPanelView {
    var onPressed: ((Point) -> Void)?
    var onDragged: ((Point) -> Void)?
    var onReleased: ((Point) -> Void)?

    private(set) var instructions: [CanvasInstruction] = []

    /// Where the press its drag follows went down.
    private(set) var pressedAt = Point(x: 0, y: 0)

    /// The gesture a press, its drag and its release come through.
    let drag: OpaquePointer

    override init() {
        drag = gtk_gesture_drag_new()!
        super.init()
        connectSignal(UnsafeMutableRawPointer(drag), "drag-begin", number: number) { _, x, y, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKCanvasView)?.pressed(x, y) }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-update", number: number) { _, x, y, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKCanvasView)?.dragged(by: x, y) }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-end", number: number) { _, x, y, data in
            MainActor.assumeIsolated { (GTKView.find(viewNumber(data)) as? GTKCanvasView)?.released(by: x, y) }
        }
        gtk_widget_add_controller(widget, drag)
    }

    /// The drawing, as its contract declares it; none draws nothing.
    func apply(_ drawing: [DrawCommand]?) {
        instructions = CanvasInstruction.instructions(drawing)
        gtk_widget_queue_draw(widget)
    }

    private func pressed(_ x: Double, _ y: Double) {
        pressedAt = Point(x: x, y: y)
        onPressed?(pressedAt)
    }

    private func dragged(by x: Double, _ y: Double) {
        onDragged?(Point(x: pressedAt.x + x, y: pressedAt.y + y))
    }

    private func released(by x: Double, _ y: Double) {
        onReleased?(Point(x: pressedAt.x + x, y: pressedAt.y + y))
    }

    /// A canvas has no size of its own: it takes the room its layout gives it.
    override func measure(across: Bool, forSize: Int32) -> Double {
        0
    }

    override func draw(_ snapshot: OpaquePointer, width: Double, height: Double) {
        // A canvas draws inside its own room, as on every platform: an instruction reaching past it paints nothing.
        var room = graphene_rect_t(
            origin: graphene_point_t(x: 0, y: 0), size: graphene_size_t(width: Float(width), height: Float(height)))
        gtk_snapshot_push_clip(snapshot, &room)
        var pen = CanvasPen()
        var saved = 0
        for instruction in instructions {
            if pen.take(instruction) {
                if instruction == .saveState {
                    gtk_snapshot_save(snapshot)
                    saved += 1
                } else if instruction == .restoreState, saved > 0 {
                    gtk_snapshot_restore(snapshot)
                    saved -= 1
                }
                continue
            }
            draw(instruction, pen: pen, on: snapshot)
        }
        for _ in 0..<saved { gtk_snapshot_restore(snapshot) }
        gtk_snapshot_pop(snapshot)
    }

    private func draw(_ instruction: CanvasInstruction, pen: CanvasPen, on snapshot: OpaquePointer) {
        switch instruction {
        case .drawLine(let from, let to):
            stroke(Self.path(of: [.move(from), .line(to)]), pen, on: snapshot)
        case .drawRectangle(let room): stroke(Self.rounded(room, radius: 0), pen, on: snapshot)
        case .drawRoundedRectangle(let room, let radius): stroke(Self.rounded(room, radius: radius), pen, on: snapshot)
        case .drawEllipse(let room): stroke(Self.oval(room), pen, on: snapshot)
        case .drawArc(let room, let start, let end, let clockwise, let closed):
            stroke(Self.path(of: CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: closed, wedge: false)), pen, on: snapshot)
        case .drawPath(let curves): stroke(Self.path(of: curves), pen, on: snapshot)
        case .fillRectangle(let room): fill(Self.rounded(room, radius: 0), pen, on: snapshot)
        case .fillRoundedRectangle(let room, let radius): fill(Self.rounded(room, radius: radius), pen, on: snapshot)
        case .fillEllipse(let room): fill(Self.oval(room), pen, on: snapshot)
        case .fillArc(let room, let start, let end, let clockwise):
            fill(Self.path(of: CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: true, wedge: true)), pen, on: snapshot)
        case .fillPath(let curves): fill(Self.path(of: curves), pen, on: snapshot)
        case .drawText(let text, let room, let across, let down):
            write(text, in: room, horizontal: across, vertical: down, pen: pen, on: snapshot)
        case .translate(let x, let y):
            var by = graphene_point_t(x: Float(x), y: Float(y))
            gtk_snapshot_translate(snapshot, &by)
        case .rotate(let degrees): gtk_snapshot_rotate(snapshot, Float(degrees))
        case .scale(let x, let y): gtk_snapshot_scale(snapshot, Float(x), Float(y))
        default: break
        }
    }

    /// `value` drawn at the pen's opacity; nil for no colour.
    private static func color(_ value: HostValue, _ pen: CanvasPen) -> GdkRGBA? {
        guard var color = GTKBrush.rgba(value) else { return nil }
        color.alpha *= Float(pen.alpha)
        return color
    }

    private func stroke(_ path: OpaquePointer, _ pen: CanvasPen, on snapshot: OpaquePointer) {
        defer { gsk_path_unref(path) }
        guard pen.strokeWidth > 0, var color = Self.color(pen.stroke, pen) else { return }
        let outline = gsk_stroke_new(Float(pen.strokeWidth))
        defer { gsk_stroke_free(outline) }
        gtk_snapshot_append_stroke(snapshot, path, outline, &color)
    }

    private func fill(_ path: OpaquePointer, _ pen: CanvasPen, on snapshot: OpaquePointer) {
        defer { gsk_path_unref(path) }
        guard var color = Self.color(pen.fill, pen) else { return }
        gtk_snapshot_append_fill(snapshot, path, GSK_FILL_RULE_WINDING, &color)
    }

    /// Writes `text` in `room`, across it and down it as the alignments say, cut to the room.
    private func write(
        _ text: String, in room: Rect, horizontal: TextAlignment, vertical: TextAlignment, pen: CanvasPen,
        on snapshot: OpaquePointer
    ) {
        guard var color = Self.color(pen.text, pen), let layout = gtk_widget_create_pango_layout(widget, text) else {
            return
        }
        defer { g_object_unref(UnsafeMutableRawPointer(layout)) }
        if let size = pen.fontSize {
            let font = pango_font_description_new()
            pango_font_description_set_absolute_size(font, size * Double(PANGO_SCALE))
            pango_layout_set_font_description(layout, font)
            pango_font_description_free(font)
        }
        pango_layout_set_width(layout, Int32(room.width * Double(PANGO_SCALE)))
        pango_layout_set_alignment(
            layout, horizontal == .center ? PANGO_ALIGN_CENTER : horizontal == .end ? PANGO_ALIGN_RIGHT : PANGO_ALIGN_LEFT)
        var measured: (width: Int32, height: Int32) = (0, 0)
        pango_layout_get_pixel_size(layout, &measured.width, &measured.height)
        let y = switch vertical {
        case .center: room.y + (room.height - Double(measured.height)) / 2
        case .end: room.y + room.height - Double(measured.height)
        case .start: room.y
        }

        gtk_snapshot_save(snapshot)
        var clip = graphene_rect_t(
            origin: graphene_point_t(x: Float(room.x), y: Float(room.y)),
            size: graphene_size_t(width: Float(room.width), height: Float(room.height)))
        gtk_snapshot_push_clip(snapshot, &clip)
        var at = graphene_point_t(x: Float(room.x), y: Float(y))
        gtk_snapshot_translate(snapshot, &at)
        gtk_snapshot_append_layout(snapshot, layout, &color)
        gtk_snapshot_pop(snapshot)
        gtk_snapshot_restore(snapshot)
    }

    /// A rectangle, its corners rounded by `radius` as far as the rectangle holds.
    private static func rounded(_ room: Rect, radius: Double) -> OpaquePointer {
        let kept = BoxArithmetic.fitted(max(0, radius), width: room.width, height: room.height)
        let corner = graphene_size_t(width: Float(kept.width), height: Float(kept.height))
        return outline(room, corner: corner)
    }

    /// The ellipse a rectangle holds.
    private static func oval(_ room: Rect) -> OpaquePointer {
        outline(room, corner: graphene_size_t(width: Float(room.width / 2), height: Float(room.height / 2)))
    }

    private static func outline(_ room: Rect, corner: graphene_size_t) -> OpaquePointer {
        let bounds = graphene_rect_t(
            origin: graphene_point_t(x: Float(room.x), y: Float(room.y)),
            size: graphene_size_t(width: Float(room.width), height: Float(room.height)))
        var shape = GTKOutline.rounded(bounds, corners: [corner, corner, corner, corner])
        let builder = gsk_path_builder_new()!
        gsk_path_builder_add_rounded_rect(builder, &shape)
        return gsk_path_builder_free_to_path(builder)
    }

    /// The path the host layer's curves draw.
    private static func path(of curves: [HostCurveCommand]) -> OpaquePointer {
        let builder = gsk_path_builder_new()!
        for curve in curves {
            switch curve {
            case .move(let to): gsk_path_builder_move_to(builder, Float(to.x), Float(to.y))
            case .line(let to): gsk_path_builder_line_to(builder, Float(to.x), Float(to.y))
            case .cubic(let first, let second, let end):
                gsk_path_builder_cubic_to(
                    builder, Float(first.x), Float(first.y), Float(second.x), Float(second.y), Float(end.x), Float(end.y))
            case .quadratic(let control, let end):
                gsk_path_builder_quad_to(builder, Float(control.x), Float(control.y), Float(end.x), Float(end.y))
            case .close: gsk_path_builder_close(builder)
            }
        }
        return gsk_path_builder_free_to_path(builder)
    }

    override func detach() {
        super.detach()
        (onPressed, onDragged, onReleased) = (nil, nil, nil)
    }
}
