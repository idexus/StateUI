// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// An Image: a panel drawing a picture from the application's folder, its own size, filling the room it is given
/// as the aspect says.
/// Design: docs/design/platforms/gtk/controls.md#pictures
@MainActor
final class GTKImageView: GTKPanelView {
    /// The picture shown, by file name, and whether it was found.
    private(set) var file = ""
    private(set) var found = false

    /// How the picture fills its room.
    private var aspect = Aspect.fit

    /// The file read, its own size in logical pixels, and whether it is an SVG, drawn at the size it shows at.
    private var path: String?
    private var size = LayoutSize(width: 0, height: 0)
    private var isVector = false

    /// The picture's pixels, and the size in device pixels they were drawn at; nil while none are.
    private var texture: OpaquePointer?
    private var drawn: LayoutSize?

    isolated deinit {
        if let texture { g_object_unref(UnsafeMutableRawPointer(texture)) }
    }

    /// Shows the picture `source` names, filling its room as `aspect` says.
    func apply(source: ImageSource?, aspect: Aspect) {
        file = source?.file ?? ""
        self.aspect = aspect
        path = GTKPictures.path(of: file)
        found = path != nil
        if !found, !file.isEmpty { GTKLog.error("no picture \(file) among the application's pictures") }

        var width: Int32 = 0
        var height: Int32 = 0
        if let path { _ = gdk_pixbuf_get_file_info(path, &width, &height) }
        size = LayoutSize(width: Double(max(width, 0)), height: Double(max(height, 0)))
        isVector = path?.lowercased().hasSuffix(".svg") == true
        replaceTexture(with: nil)
        drawn = nil
        placingLayout?.invalidateMeasurements()
        gtk_widget_queue_resize(widget)
    }

    /// The picture's own size, whatever room is offered.
    /// Design: docs/design/platforms/gtk/controls.md#pictures
    override func measure(across: Bool, forSize: Int32) -> Double {
        across ? size.width : size.height
    }

    override func allocate(width: Double, height: Double) {
        read(for: LayoutSize(width: width, height: height))
    }

    /// Reads the picture's pixels for a room: a bitmap once, an SVG at the size it shows at in the room, at the
    /// display's scale - again only for more pixels, so a size in motion does not read it every frame. An SVG
    /// keeps its own proportions as it is read, so a stretched one is read covering the room and drawn squeezed
    /// into it.
    /// Design: docs/design/platforms/gtk/controls.md#pictures
    private func read(for room: LayoutSize) {
        guard let path, size.width > 0, size.height > 0, room.width > 0, room.height > 0 else { return }
        guard isVector else {
            if texture == nil { replaceTexture(with: gdk_texture_new_from_filename(path, nil)) }
            return
        }

        let covering = max(room.width / size.width, room.height / size.height)
        let placed = place(in: room)
        let shown = aspect == .stretch
            ? LayoutSize(width: size.width * covering, height: size.height * covering)
            : LayoutSize(width: placed.width, height: placed.height)
        let scale = Double(max(gtk_widget_get_scale_factor(widget), 1))
        let wanted = LayoutSize(width: (shown.width * scale).rounded(.up), height: (shown.height * scale).rounded(.up))
        if let drawn, drawn.width >= wanted.width, drawn.height >= wanted.height { return }

        guard let pixbuf = gdk_pixbuf_new_from_file_at_scale(path, Int32(wanted.width), Int32(wanted.height), 1, nil)
        else { return }
        replaceTexture(with: gdk_texture_new_for_pixbuf(pixbuf))
        g_object_unref(UnsafeMutableRawPointer(pixbuf))
        drawn = wanted
        gtk_widget_queue_draw(widget)
    }

    /// Where the picture stands in a room at the origin, as the aspect says.
    private func place(in room: LayoutSize) -> Rect {
        let across = room.width / size.width
        let down = room.height / size.height
        let scale: Double = switch aspect {
        case .fit: min(across, down)
        case .fill: max(across, down)
        case .stretch, .center: 1
        }
        guard aspect != .stretch else { return Rect(x: 0, y: 0, width: room.width, height: room.height) }
        let width = size.width * scale
        let height = size.height * scale
        return Rect(x: (room.width - width) / 2, y: (room.height - height) / 2, width: width, height: height)
    }

    override func draw(_ snapshot: OpaquePointer, width: Double, height: Double) {
        read(for: LayoutSize(width: width, height: height))
        guard let texture else { return }

        let place = place(in: LayoutSize(width: width, height: height))
        var room = graphene_rect_t(
            origin: graphene_point_t(x: 0, y: 0), size: graphene_size_t(width: Float(width), height: Float(height)))
        var bounds = graphene_rect_t(
            origin: graphene_point_t(x: Float(place.x), y: Float(place.y)),
            size: graphene_size_t(width: Float(place.width), height: Float(place.height)))
        gtk_snapshot_push_clip(snapshot, &room)
        gtk_snapshot_append_texture(snapshot, texture, &bounds)
        gtk_snapshot_pop(snapshot)
    }

    private func replaceTexture(with texture: OpaquePointer?) {
        if let old = self.texture { g_object_unref(UnsafeMutableRawPointer(old)) }
        self.texture = texture
    }
}
