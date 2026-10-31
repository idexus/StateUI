// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// An Image: a panel drawing a picture - from the application's folder, the theme's icon, or bytes - its own size,
/// filling the room it is given as the aspect says.
/// Design: docs/design/platforms/gtk/controls.md#pictures
@MainActor
final class GTKImageView: GTKPanelView {
    /// The picture shown, and whether it was found.
    private(set) var picture: HostPicture?
    private(set) var found = false

    /// How the picture fills its room.
    private(set) var aspect = ContentMode.fit

    /// The color written for the words an icon stands beside; nil draws it in the color the theme gives them.
    var wordsColor: GdkRGBA? {
        didSet { if case .icon = picture { gtk_widget_queue_draw(widget) } }
    }

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

    /// Shows `picture`, filling its room as `aspect` says.
    func apply(picture: HostPicture?, aspect: ContentMode) {
        self.picture = picture
        self.aspect = aspect
        path = picture?.file.flatMap(GTKPictures.path(of:))
        replaceTexture(with: nil)
        drawn = nil

        var width: Int32 = 0
        var height: Int32 = 0
        switch picture {
        case .file:
            if let path { _ = gdk_pixbuf_get_file_info(path, &width, &height) }
        case .bytes(let bytes):
            // Read at once, at one pixel a logical pixel.
            replaceTexture(with: GTKPictures.texture(of: bytes))
            if let texture { (width, height) = (gdk_texture_get_width(texture), gdk_texture_get_height(texture)) }
        case .icon:
            // The theme's icon size, which GTK draws its own icons at.
            (width, height) = (Self.iconSize, Self.iconSize)
        case nil:
            break
        }
        found = picture == nil || width > 0
        if !found { GTKRenderer.log.error("no picture \(picture?.identity ?? "") among the application's pictures") }
        size = LayoutSize(width: Double(max(width, 0)), height: Double(max(height, 0)))
        isVector = path?.lowercased().hasSuffix(".svg") == true
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
    /// display's scale - a stretched one at the room's own, sharp both ways - and again only for more pixels, so a
    /// size in motion does not read it every frame (`PictureArithmetic.vectorPixels`, `drawsAgain`).
    /// Design: docs/design/platforms/gtk/controls.md#pictures
    private func read(for room: LayoutSize) {
        guard let path, size.width > 0, size.height > 0, room.width > 0, room.height > 0 else { return }
        guard isVector else {
            if texture == nil { replaceTexture(with: gdk_texture_new_from_filename(path, nil)) }
            return
        }

        let scale = Double(max(gtk_widget_get_scale_factor(widget), 1))
        let wanted = PictureArithmetic.vectorPixels(size, in: room, aspect: aspect, scale: scale)
        guard wanted.width > 0, wanted.height > 0, PictureArithmetic.drawsAgain(drawn: drawn, for: wanted) else { return }

        let keepsProportions: gboolean = aspect == .stretch ? 0 : 1
        guard let pixbuf = gdk_pixbuf_new_from_file_at_scale(
            path, Int32(wanted.width), Int32(wanted.height), keepsProportions, nil)
        else { return }
        // The pixbuf's own pixels, eight bits a channel, its alpha straight where it has one.
        let pixels = gdk_pixbuf_read_pixel_bytes(pixbuf)
        let format = gdk_pixbuf_get_has_alpha(pixbuf) != 0 ? GDK_MEMORY_R8G8B8A8 : GDK_MEMORY_R8G8B8
        replaceTexture(with: gdk_memory_texture_new(
            gdk_pixbuf_get_width(pixbuf), gdk_pixbuf_get_height(pixbuf), format, pixels,
            gsize(gdk_pixbuf_get_rowstride(pixbuf))))
        g_bytes_unref(pixels)
        g_object_unref(UnsafeMutableRawPointer(pixbuf))
        drawn = wanted
        gtk_widget_queue_draw(widget)
    }

    /// Where the picture stands in a room at the origin, as the aspect says (`PictureArithmetic.place`).
    private func place(in room: LayoutSize) -> Rect {
        PictureArithmetic.place(size, in: room, aspect: aspect)
    }

    override func draw(_ snapshot: OpaquePointer, width: Double, height: Double) {
        if case .icon(let icon) = picture {
            return drawIcon(icon, snapshot, in: place(in: LayoutSize(width: width, height: height)))
        }
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

    /// The size, in logical pixels, GTK draws an icon at: `GTK_ICON_SIZE_NORMAL`'s.
    static let iconSize: Int32 = 16

    /// Draws `icon`, the theme's symbolic one, filling `place` in the color of the words the image stands among -
    /// the color written for them, else the theme's.
    /// Design: docs/design/platforms/gtk/drawing.md#icons
    private func drawIcon(_ icon: Icon, _ snapshot: OpaquePointer, in place: Rect) {
        guard place.width > 0, place.height > 0 else { return }
        let theme = gtk_icon_theme_get_for_display(gtk_widget_get_display(widget))
        let scale = max(gtk_widget_get_scale_factor(widget), 1)
        let side = Int32(min(place.width, place.height).rounded(.up))
        guard let paintable = gtk_icon_theme_lookup_icon(
            theme, icon.name(in: theme), nil, side, scale, GTK_TEXT_DIR_NONE, GtkIconLookupFlags(rawValue: 0))
        else { return }
        defer { g_object_unref(UnsafeMutableRawPointer(paintable)) }

        var color = wordsColor ?? GdkRGBA()
        if wordsColor == nil { gtk_widget_get_color(widget, &color) }
        var corner = graphene_point_t(x: Float(place.x), y: Float(place.y))
        gtk_snapshot_save(snapshot)
        gtk_snapshot_translate(snapshot, &corner)
        gtk_symbolic_paintable_snapshot_symbolic(paintable, snapshot, place.width, place.height, &color, 1)
        gtk_snapshot_restore(snapshot)
    }

    private func replaceTexture(with texture: OpaquePointer?) {
        if let old = self.texture { g_object_unref(UnsafeMutableRawPointer(old)) }
        self.texture = texture
    }
}
