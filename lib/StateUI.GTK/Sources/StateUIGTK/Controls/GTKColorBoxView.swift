// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A ColorBox: a panel painting one colour, which takes the room its layout gives it and asks for none.
@MainActor
final class GTKColorBoxView: GTKPanelView {
    private var color: GdkRGBA?

    /// The corners' radii in GSK's order: top left, top right, bottom right, bottom left.
    private var radii = [0.0, 0.0, 0.0, 0.0]

    /// The box's colour, and the radii of its corners - one for all four, or four in StateUI's order: top left,
    /// top right, bottom left, bottom right; nil draws no colour.
    func apply(color: HostValue?, corners: HostValue?) {
        radii = BoxArithmetic.clockwise(corners.flatMap(CornerRadius.init(propValue:)))
        self.color = color.flatMap(GTKBrush.rgba)
        gtk_widget_queue_draw(widget)
    }

    override func draw(_ snapshot: OpaquePointer, width: Double, height: Double) {
        guard var color else { return }
        var bounds = graphene_rect_t(
            origin: graphene_point_t(x: 0, y: 0), size: graphene_size_t(width: Float(width), height: Float(height)))
        guard radii.contains(where: { $0 > 0 }) else {
            gtk_snapshot_append_color(snapshot, &color, &bounds)
            return
        }

        let corners = radii.map { radius in
            let fitted = BoxArithmetic.fitted(radius, width: width, height: height)
            return graphene_size_t(width: Float(fitted.width), height: Float(fitted.height))
        }
        var outline = GTKOutline.rounded(bounds, corners: corners)
        gtk_snapshot_push_rounded_clip(snapshot, &outline)
        gtk_snapshot_append_color(snapshot, &color, &bounds)
        gtk_snapshot_pop(snapshot)
    }
}
