// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0
//
// Draws an application's launcher icon for its Android head, from the artwork
// in Resources/AppIcon: an adaptive icon, @mipmap/appicon, whose background is
// appicon_bkg.svg and whose foreground - and monochrome layer, for a themed
// launcher - is appicon_mark.svg. Each layer is a 108 dp canvas at every
// density; a launcher shows the middle 72 dp of it, so the mark is drawn at
// two thirds of the canvas, where it stands as large as it does elsewhere.
// Only what changed is drawn again.
//
// USAGE: draw-app-icon <Resources/AppIcon> <res>

import AppKit
import ImageIO

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("USAGE: draw-app-icon <Resources/AppIcon> <res>")
    exit(1)
}

let files = FileManager.default
let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
let target = URL(fileURLWithPath: arguments[2], isDirectory: true)
let background = source.appendingPathComponent("appicon_bkg.svg")
let mark = source.appendingPathComponent("appicon_mark.svg")

/// A layer's canvas, in dp, and how much of it the mark takes.
let canvas = 108.0
let markScale = 2.0 / 3.0

/// Android's densities, as a pixel is to a dp at each.
let densities: [(folder: String, scale: Double)] = [
    ("mipmap-mdpi", 1), ("mipmap-hdpi", 1.5), ("mipmap-xhdpi", 2), ("mipmap-xxhdpi", 3), ("mipmap-xxxhdpi", 4),
]

func modified(_ url: URL) -> Date? {
    try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
}

/// `svg` drawn square on a `pixels`-wide canvas, taking `fraction` of it about its middle.
func draw(_ svg: URL, pixels: Int, fraction: Double, to png: URL) throws {
    guard let image = NSImage(contentsOf: svg), image.size.width > 0, image.size.height > 0 else {
        throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: svg.path])
    }
    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }

    let side = Double(pixels) * fraction
    let inset = (Double(pixels) - side) / 2
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    image.draw(in: NSRect(x: inset, y: inset, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()

    guard let drawn = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, drawn, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let adaptive = """
    <?xml version="1.0" encoding="utf-8"?>
    <!-- Drawn by .scripts/Android/draw-app-icon.swift from Resources/AppIcon. -->
    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
        <background android:drawable="@mipmap/appicon_background" />
        <foreground android:drawable="@mipmap/appicon_foreground" />
        <monochrome android:drawable="@mipmap/appicon_foreground" />
    </adaptive-icon>

    """

do {
    for artwork in [background, mark] where !files.fileExists(atPath: artwork.path) {
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: artwork.path])
    }

    for density in densities {
        let folder = target.appendingPathComponent(density.folder)
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let pixels = Int((canvas * density.scale).rounded())

        for (artwork, name, fraction) in [(background, "appicon_background", 1.0), (mark, "appicon_foreground", markScale)] {
            let png = folder.appendingPathComponent("\(name).png")
            if let made = modified(png), let written = modified(artwork), made >= written { continue }
            try draw(artwork, pixels: pixels, fraction: fraction, to: png)
        }
    }

    let anydpi = target.appendingPathComponent("mipmap-anydpi-v26")
    try files.createDirectory(at: anydpi, withIntermediateDirectories: true)
    try adaptive.write(to: anydpi.appendingPathComponent("appicon.xml"), atomically: true, encoding: .utf8)
} catch {
    print("ERROR: \(error.localizedDescription)")
    exit(1)
}
