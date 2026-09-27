// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0
//
// Draws an application's icon for its UIKit head, from the artwork in
// Resources/AppIcon: an asset catalog whose AppIcon is one 1024-pixel square -
// appicon_bkg.svg over the whole of it and appicon_mark.svg in its middle,
// opaque, as iOS asks of an icon it rounds itself. The mark takes as much of
// the square as it takes of what a launcher shows elsewhere. Only what changed
// is drawn again.
//
// USAGE: draw-app-icon <Resources/AppIcon> <Assets.xcassets>

import AppKit
import ImageIO

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("USAGE: draw-app-icon <Resources/AppIcon> <Assets.xcassets>")
    exit(1)
}

let files = FileManager.default
let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
let catalog = URL(fileURLWithPath: arguments[2], isDirectory: true)
let background = source.appendingPathComponent("appicon_bkg.svg")
let mark = source.appendingPathComponent("appicon_mark.svg")
let iconSet = catalog.appendingPathComponent("AppIcon.appiconset")
let png = iconSet.appendingPathComponent("appicon.png")
let pixels = 1024

func modified(_ url: URL) -> Date? {
    try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
}

func image(_ svg: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: svg), image.size.width > 0, image.size.height > 0 else {
        throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: svg.path])
    }
    return image
}

let contents = """
    {
      "images" : [
        { "filename" : "appicon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
      ],
      "info" : { "author" : "stateui", "version" : 1 }
    }

    """

do {
    for artwork in [background, mark] where !files.fileExists(atPath: artwork.path) {
        throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: artwork.path])
    }
    try files.createDirectory(at: iconSet, withIntermediateDirectories: true)
    try "{ \"info\" : { \"author\" : \"stateui\", \"version\" : 1 } }\n"
        .write(to: catalog.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    try contents.write(to: iconSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    let newest = [background, mark].compactMap(modified).max()
    if let made = modified(png), let newest, made >= newest { exit(0) }

    guard let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw CocoaError(.fileWriteUnknown) }

    let side = Double(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    try image(background).draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    try image(mark).draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()

    guard let drawn = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(png as CFURL, "public.png" as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, drawn, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
} catch {
    print("ERROR: \(error.localizedDescription)")
    exit(1)
}
