// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// An application's picture - the file its name stands for, and where it stands in its room - the same on every
/// host.
/// Design: docs/design/host/layout.md#a-picture
@_spi(Host) public enum PictureArithmetic {
    /// The files a picture's name may stand for, in the order a host looks for them: the name, then - for a PNG -
    /// an SVG of the same name, which a host drawing vector pictures reads in its place.
    public static func files(for name: String) -> [String] {
        guard name.lowercased().hasSuffix(".png") else { return [name] }
        return [name, String(name.dropLast(4)) + ".svg"]
    }

    /// The files a picture `name` stands for where a host draws no SVG, in order, each with how many pixels a point
    /// it holds: its own at one, an SVG's drawing - made three times over as the application is built, as
    /// `<name>@3x.png` - at three.
    public static func drawnFiles(for name: String) -> [(file: String, scale: Int)] {
        files(for: name).map { file in
            file.lowercased().hasSuffix(".svg") ? (String(file.dropLast(4)) + "@3x.png", 3) : (file, 1)
        }
    }

    /// A picture `size` across as a bar or a tab shows it: `height` tall - the platform's icon size - and as wide as
    /// its shape makes it, whatever size it is drawn at elsewhere. A picture of no height stays as it is.
    public static func glyph(_ size: LayoutSize, height: Double) -> LayoutSize {
        guard size.height > 0 else { return size }
        return LayoutSize(width: size.width * height / size.height, height: height)
    }

    /// Where a picture `size` across stands in a room at the origin, as `aspect` says: fitted in or covering it,
    /// its proportions kept, or at its own size, in its middle; stretched over the whole of it. A picture of no
    /// size stands nowhere.
    public static func place(_ size: LayoutSize, in room: LayoutSize, aspect: ContentMode) -> Rect {
        guard aspect != .stretch else { return Rect(x: 0, y: 0, width: room.width, height: room.height) }
        guard size.width > 0, size.height > 0 else {
            return Rect(x: room.width / 2, y: room.height / 2, width: 0, height: 0)
        }
        let across = room.width / size.width
        let down = room.height / size.height
        let scale: Double = switch aspect {
        case .fit: min(across, down)
        case .fill: max(across, down)
        case .stretch, .center: 1
        }
        let width = size.width * scale
        let height = size.height * scale
        return Rect(x: (room.width - width) / 2, y: (room.height - height) / 2, width: width, height: height)
    }
}
