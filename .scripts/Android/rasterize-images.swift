// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0
//
// Draws an application's pictures for its Android head: every SVG three times
// over, in sRGB, as <name>@3x.png, and every other picture copied as it is.
// Android draws no SVG, and a picture three times over is what its densest
// common screens show at one pixel a pixel. Only what changed is drawn again,
// and a picture whose file went away goes with it.
//
// USAGE: rasterize-images <Resources/Images> <assets/images>

import AppKit
import ImageIO

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("USAGE: rasterize-images <Resources/Images> <assets/images>")
    exit(1)
}

let files = FileManager.default
let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
let target = URL(fileURLWithPath: arguments[2], isDirectory: true)
let scale = 3.0
let pictures: Set<String> = ["svg", "png", "jpg", "jpeg", "webp", "gif"]

func modified(_ url: URL) -> Date? {
    try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
}

func draw(_ svg: URL, to png: URL) throws {
    guard let image = NSImage(contentsOf: svg), image.size.width > 0, image.size.height > 0 else {
        throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: svg.path])
    }

    let width = Int((image.size.width * scale).rounded())
    let height = Int((image.size.height * scale).rounded())
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }

    context.scaleBy(x: scale, y: scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: NSRect(origin: .zero, size: image.size))
    NSGraphicsContext.restoreGraphicsState()

    guard let drawn = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, drawn, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

do {
    try files.createDirectory(at: target, withIntermediateDirectories: true)
    var kept = Set<String>()

    for name in (try? files.contentsOfDirectory(atPath: source.path)) ?? [] {
        let from = source.appendingPathComponent(name)
        let kind = from.pathExtension.lowercased()
        guard pictures.contains(kind) else { continue }

        let drawn = kind == "svg" ? from.deletingPathExtension().lastPathComponent + "@3x.png" : name
        let to = target.appendingPathComponent(drawn)
        kept.insert(drawn)
        if let made = modified(to), let written = modified(from), made >= written { continue }

        if kind == "svg" {
            try draw(from, to: to)
        } else {
            try? files.removeItem(at: to)
            try files.copyItem(at: from, to: to)
        }
    }

    for name in try files.contentsOfDirectory(atPath: target.path) where !kept.contains(name) {
        try files.removeItem(at: target.appendingPathComponent(name))
    }
} catch {
    print("ERROR: \(error.localizedDescription)")
    exit(1)
}
