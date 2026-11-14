// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(ImageIO)
import CoreGraphics
import ImageIO
#endif

/// Pictures drawn for the heads that need them drawn, on any machine, by `resvg`: an SVG to a PNG at a scale, an
/// application's pictures to a folder of PNGs, a macOS icon set, an iOS icon's asset catalog and an Android launcher
/// icon - StateUI's own policy of sizes, densities and layers, the renderer's pixels the same everywhere.
/// Design: docs/design/tooling/pictures.md
struct Pictures: Sendable {
    let renderer: Resvg

    /// The picture files the folders hold and carry over; only SVGs are drawn.
    static let kinds: Set<String> = ["svg", "png", "jpg", "jpeg", "webp", "gif"]

    /// Draws `svg` into `png`, `scale` times its own size, in sRGB.
    func draw(_ svg: URL, scale: Double, to png: URL) async throws {
        try await renderer.draw(svg, to: png, zoom: scale)
    }

    /// Draws every SVG of `images` into `target` as `<name>@<scale>x.png` and copies every other picture as it is -
    /// only what changed since it was drawn - and removes from `target` what `images` no longer holds.
    func draw(_ images: URL, into target: URL, scale: Int = 3) async throws {
        let files = FileManager.default
        try files.createDirectory(at: target, withIntermediateDirectories: true)
        var kept = Set<String>()
        for name in try files.contentsOfDirectory(atPath: images.path).sorted() {
            let from = images.appendingPathComponent(name)
            let kind = from.pathExtension.lowercased()
            guard Self.kinds.contains(kind) else { continue }
            let made = kind == "svg" ? from.deletingPathExtension().lastPathComponent + "@\(scale)x.png" : name
            let to = target.appendingPathComponent(made)
            kept.insert(made)
            if let drawn = Self.modified(to), let written = Self.modified(from), drawn >= written { continue }
            if kind == "svg" {
                try await draw(from, scale: Double(scale), to: to)
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
    func drawIconSet(_ svg: URL, into iconset: URL) async throws {
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            try await drawLayers([(svg, 1)], size: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
            try await drawLayers([(svg, 1)], size: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
        }
    }

    /// An iOS icon's asset catalog drawn into `catalog`: its `AppIcon` one opaque 1024-pixel square, `background` over
    /// the whole of it and `mark` over that - drawn again only where either changed since.
    func drawAppIcon(background: URL, mark: URL, into catalog: URL) async throws {
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
        if let drawn = Self.modified(png), let newest = [background, mark].compactMap(Self.modified).max(), drawn >= newest { return }
        try await drawLayers([(background, 1), (mark, 1)], size: 1024, to: png)
        try Self.dropAlpha(png)
    }

    /// Android's densities: each one's mipmap folder, and its pixels to a dp.
    static let androidDensities: [(folder: String, scale: Double)] = [
        ("mipmap-mdpi", 1), ("mipmap-hdpi", 1.5), ("mipmap-xhdpi", 2), ("mipmap-xxhdpi", 3), ("mipmap-xxxhdpi", 4),
    ]

    /// An Android launcher icon drawn into `res`: the adaptive `@mipmap/appicon`, `background` its background and
    /// `mark` its foreground and monochrome layer, each a 108 dp canvas at every density, the mark at two thirds of it
    /// about its middle - where it stands as large as a launcher shows it elsewhere - drawn again only where changed.
    func drawAdaptiveIcon(background: URL, mark: URL, into res: URL) async throws {
        let files = FileManager.default
        for density in Self.androidDensities {
            let folder = res.appendingPathComponent(density.folder)
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            let pixels = Int((108 * density.scale).rounded())
            for (artwork, name, fraction) in [(background, "appicon_background", 1.0), (mark, "appicon_foreground", 2.0 / 3)] {
                let png = folder.appendingPathComponent("\(name).png")
                if let drawn = Self.modified(png), let written = Self.modified(artwork), drawn >= written { continue }
                try await drawLayers([(artwork, fraction)], size: pixels, to: png)
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

    /// Draws `layers`, the first lowest, into a `size`-pixel square `png`, each over its fraction of it about the
    /// middle - through a picture that holds them, which the renderer reads.
    func drawLayers(_ layers: [(svg: URL, fraction: Double)], size: Int, to png: URL) async throws {
        let holder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-layers-\(UUID().uuidString).svg")
        defer { try? FileManager.default.removeItem(at: holder) }
        try Data(Self.layered(layers, size: size).utf8).write(to: holder)
        try await renderer.draw(holder, to: png)
    }

    /// The SVG holding `layers` over a `size`-unit square, each stretched over its fraction of it about the middle.
    static func layered(_ layers: [(svg: URL, fraction: Double)], size: Int) -> String {
        let images = layers.map { layer in
            let side = Double(size) * layer.fraction
            let edge = (Double(size) - side) / 2
            let path = layer.svg.path.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "<", with: "&lt;")
            return "<image xlink:href=\"\(path)\" x=\"\(edge)\" y=\"\(edge)\" width=\"\(side)\" height=\"\(side)\" preserveAspectRatio=\"none\"/>"
        }
        return """
            <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="\(size)" height="\(size)" viewBox="0 0 \(size) \(size)">
            \(images.joined(separator: "\n"))
            </svg>

            """
    }

    /// `png` written again with no alpha channel - an iOS icon is opaque: an Apple asset's own step, on a Mac.
    static func dropAlpha(_ png: URL) throws {
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithURL(png as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: png.path]) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let opaque = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: png.path]) }
        CGImageDestinationAddImage(destination, opaque, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: png.path]) }
        #endif
    }

    private static func modified(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
