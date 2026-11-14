// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import AppKit
import Foundation
import ImageIO

/// Pictures drawn on a Mac for the heads that need them drawn: an SVG to a PNG at a scale, an application's pictures
/// to a folder of PNGs, a macOS icon, an iOS icon's asset catalog, and an Android launcher icon.
/// Design: docs/design/tooling/pictures.md
public enum ApplePictures {
    /// The picture files the folders hold and carry over; only SVGs are drawn.
    static let kinds: Set<String> = ["svg", "png", "jpg", "jpeg", "webp", "gif"]

    /// Draws `svg` into `png`, `scale` times its own size, in sRGB.
    public static func draw(_ svg: URL, scale: Double, to png: URL) throws {
        try draw(svg, width: nil, to: png, scale: scale)
    }

    /// Draws every SVG of `images` into `target` as `<name>@<scale>x.png` and copies every other picture as it is -
    /// only what changed since it was drawn - and removes from `target` what `images` no longer holds.
    public static func draw(_ images: URL, into target: URL, scale: Int = 3) throws {
        let files = FileManager.default
        try files.createDirectory(at: target, withIntermediateDirectories: true)
        var kept = Set<String>()
        for name in try files.contentsOfDirectory(atPath: images.path).sorted() {
            let from = images.appendingPathComponent(name)
            let kind = from.pathExtension.lowercased()
            guard kinds.contains(kind) else { continue }
            let made = kind == "svg" ? from.deletingPathExtension().lastPathComponent + "@\(scale)x.png" : name
            let to = target.appendingPathComponent(made)
            kept.insert(made)
            if let drawn = modified(to), let written = modified(from), drawn >= written { continue }
            if kind == "svg" {
                try draw(from, scale: Double(scale), to: to)
            } else {
                try? files.removeItem(at: to)
                try files.copyItem(at: from, to: to)
            }
        }
        for name in try files.contentsOfDirectory(atPath: target.path) where !kept.contains(name) {
            try files.removeItem(at: target.appendingPathComponent(name))
        }
    }

    /// The pictures of a macOS icon set drawn from `svg` into `iconset` - 16, 32, 128, 256 and 512 points at one
    /// and two pixels a point - as `iconutil` reads them.
    public static func drawIconSet(_ svg: URL, into iconset: URL) throws {
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            try draw(svg, width: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
            try draw(svg, width: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
        }
    }

    /// An iOS icon's asset catalog drawn into `catalog`: its `AppIcon` one opaque 1024-pixel square, `background` over
    /// the whole of it and `mark` over that - drawn again only where either changed since.
    public static func drawAppIcon(background: URL, mark: URL, into catalog: URL) throws {
        let files = FileManager.default
        let iconSet = catalog.appendingPathComponent("AppIcon.appiconset")
        let png = iconSet.appendingPathComponent("appicon.png")
        try files.createDirectory(at: iconSet, withIntermediateDirectories: true)
        try Data(#"{ "info" : { "author" : "stateui", "version" : 1 } }"#.utf8 + [10])
            .write(to: catalog.appendingPathComponent("Contents.json"))
        try Data(#"""
            { "images" : [ { "filename" : "appicon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
              "info" : { "author" : "stateui", "version" : 1 } }

            """#.utf8).write(to: iconSet.appendingPathComponent("Contents.json"))
        if let drawn = modified(png), let newest = [background, mark].compactMap(modified).max(), drawn >= newest { return }
        try draw([background, mark], width: 1024, to: png, opaque: true)
    }

    /// Android's densities: each one's mipmap folder, and its pixels to a dp.
    static let androidDensities: [(folder: String, scale: Double)] = [
        ("mipmap-mdpi", 1), ("mipmap-hdpi", 1.5), ("mipmap-xhdpi", 2), ("mipmap-xxhdpi", 3), ("mipmap-xxxhdpi", 4),
    ]

    /// An Android launcher icon drawn into `res`: the adaptive `@mipmap/appicon`, `background` its background and
    /// `mark` its foreground and monochrome layer, each a 108 dp canvas at every density, the mark at two thirds of it
    /// about its middle - where it stands as large as a launcher shows it elsewhere - drawn again only where changed.
    public static func drawAdaptiveIcon(background: URL, mark: URL, into res: URL) throws {
        let files = FileManager.default
        for density in androidDensities {
            let folder = res.appendingPathComponent(density.folder)
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            let pixels = Int((108 * density.scale).rounded())
            for (artwork, name, fraction) in [(background, "appicon_background", 1.0), (mark, "appicon_foreground", 2.0 / 3)] {
                let png = folder.appendingPathComponent("\(name).png")
                if let drawn = modified(png), let written = modified(artwork), drawn >= written { continue }
                try draw([artwork], width: pixels, to: png, fraction: fraction)
            }
        }
        let anydpi = res.appendingPathComponent("mipmap-anydpi-v26")
        try files.createDirectory(at: anydpi, withIntermediateDirectories: true)
        try Data("""
            <?xml version="1.0" encoding="utf-8"?>
            <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
                <background android:drawable="@mipmap/appicon_background" />
                <foreground android:drawable="@mipmap/appicon_foreground" />
                <monochrome android:drawable="@mipmap/appicon_foreground" />
            </adaptive-icon>

            """.utf8).write(to: anydpi.appendingPathComponent("appicon.xml"))
    }

    /// Draws `svg` into `png`: `width` pixels square where given, else `scale` times its own size.
    private static func draw(_ svg: URL, width: Int?, to png: URL, scale: Double = 1) throws {
        try draw([svg], width: width, to: png, scale: scale)
    }

    /// Draws `layers`, the first lowest, into `png` - each over `fraction` of the picture about its middle, the first's
    /// size giving it - and `opaque`, with no alpha.
    private static func draw(
        _ layers: [URL], width: Int?, to png: URL, scale: Double = 1, opaque: Bool = false, fraction: Double = 1
    ) throws {
        let images = try layers.map { svg in
            guard let image = NSImage(contentsOf: svg), image.size.width > 0, image.size.height > 0 else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: svg.path])
            }
            return image
        }
        let size = images[0].size
        let (pixelsWide, pixelsHigh) = width.map { ($0, $0) }
            ?? (Int((size.width * scale).rounded()), Int((size.height * scale).rounded()))
        let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: alpha.rawValue)
        else { throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: png.path]) }
        let (wide, high) = (Double(pixelsWide) * fraction, Double(pixelsHigh) * fraction)
        let whole = NSRect(x: (Double(pixelsWide) - wide) / 2, y: (Double(pixelsHigh) - high) / 2, width: wide, height: high)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for image in images { image.draw(in: whole) }
        NSGraphicsContext.restoreGraphicsState()
        guard let drawn = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: png.path]) }
        CGImageDestinationAddImage(destination, drawn, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: png.path])
        }
    }

    private static func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
#endif
