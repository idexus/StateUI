// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import AppKit
import Foundation
import ImageIO

/// Pictures drawn on a Mac for the heads that need them drawn: an SVG to a PNG at a scale, an application's pictures
/// to a folder of PNGs, and a macOS icon.
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

    /// Draws `svg` into `png`: `width` pixels square where given, else `scale` times its own size.
    private static func draw(_ svg: URL, width: Int?, to png: URL, scale: Double = 1) throws {
        guard let image = NSImage(contentsOf: svg), image.size.width > 0, image.size.height > 0 else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: svg.path])
        }
        let (pixelsWide, pixelsHigh) = width.map { ($0, $0) }
            ?? (Int((image.size.width * scale).rounded()), Int((image.size.height * scale).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: png.path]) }
        context.scaleBy(x: CGFloat(pixelsWide) / image.size.width, y: CGFloat(pixelsHigh) / image.size.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: NSRect(origin: .zero, size: image.size))
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
