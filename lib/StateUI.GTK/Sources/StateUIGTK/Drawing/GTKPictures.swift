// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK

/// The application's pictures: the files of the `Images` folder beside the executable, found by the name the tree
/// gives them.
/// Design: docs/design/platforms/gtk/drawing.md#the-applications-pictures
@MainActor
enum GTKPictures {
    /// The folder pictures are read from.
    static var folder = besideExecutable()

    /// The file `name` names; a PNG the folder holds as an SVG is the SVG. Nil for none.
    static func path(of name: String) -> String? {
        var names = [name]
        if name.lowercased().hasSuffix(".png") { names.append(String(name.dropLast(4)) + ".svg") }
        return names.map { folder + "/" + $0 }.first { g_file_test($0, G_FILE_TEST_IS_REGULAR) != 0 }
    }

    /// An image showing the picture `name` names as an icon `size` logical pixels across, which GTK draws at the
    /// display's scale; nil where there is no such picture.
    static func icon(named name: String, size: Int32) -> GTKWidget? {
        guard let path = path(of: name), let file = g_file_new_for_path(path) else { return nil }
        let icon = g_file_icon_new(file)
        let image = gtk_image_new_from_gicon(icon)
        g_object_unref(UnsafeMutableRawPointer(icon))
        g_object_unref(UnsafeMutableRawPointer(file))
        if let image { gtk_image_set_pixel_size(image.opaque, size) }
        return image
    }

    private static func besideExecutable() -> String {
        guard let link = g_file_read_link("/proc/self/exe", nil) else { return "Images" }
        defer { g_free(link) }
        guard let folder = g_path_get_dirname(link) else { return "Images" }
        defer { g_free(folder) }
        return String(cString: folder) + "/Images"
    }
}
