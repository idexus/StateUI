// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// The pictures views show: the application's files of the `Images` folder beside the executable, found by the name
/// the tree gives them; the theme's icons; and pictures given as bytes.
/// Design: docs/design/platforms/gtk/drawing.md#the-applications-pictures
@MainActor
enum GTKPictures {
    /// The folder pictures are read from.
    static var folder = besideExecutable()

    /// The file `name` names (`PictureArithmetic.files`): a PNG the folder holds as an SVG is the SVG. Nil for none.
    static func path(of name: String) -> String? {
        PictureArithmetic.files(for: name).map { folder + "/" + $0 }.first { g_file_test($0, STATEUI_FILE_TEST_IS_REGULAR) != 0 }
    }

    /// An image showing `picture` as an icon `size` logical pixels across, which GTK draws at the display's scale -
    /// the theme's symbolic one in the color of the words around it; nil where there is no such picture.
    static func icon(_ picture: HostPicture, size: Int32) -> GTKWidget? {
        let image: GTKWidget?
        switch picture {
        case .file(let name):
            guard let path = path(of: name), let file = g_file_new_for_path(path) else { return nil }
            let icon = g_file_icon_new(file)
            image = gtk_image_new_from_gicon(icon)
            g_object_unref(UnsafeMutableRawPointer(icon))
            g_object_unref(UnsafeMutableRawPointer(file))
        case .icon(let icon):
            image = gtk_image_new_from_icon_name(icon.name(in: gtk_icon_theme_get_for_display(gdk_display_get_default())))
        case .bytes(let bytes):
            guard let texture = texture(of: bytes) else { return nil }
            image = gtk_image_new_from_paintable(texture)
            g_object_unref(UnsafeMutableRawPointer(texture))
        }
        if let image { gtk_image_set_pixel_size(image.opaque, size) }
        return image
    }

    /// The pixels `bytes` encode - a PNG, a JPEG, a TIFF - at one pixel a logical pixel; nil where they encode none.
    static func texture(of bytes: [UInt8]) -> OpaquePointer? {
        let held = bytes.withUnsafeBytes { g_bytes_new($0.baseAddress, gsize($0.count)) }
        defer { g_bytes_unref(held) }
        return gdk_texture_new_from_bytes(held, nil)
    }

    private static func besideExecutable() -> String {
        guard let link = g_file_read_link("/proc/self/exe", nil) else { return "Images" }
        defer { g_free(link) }
        guard let folder = g_path_get_dirname(link) else { return "Images" }
        defer { g_free(folder) }
        return String(cString: folder) + "/Images"
    }
}
