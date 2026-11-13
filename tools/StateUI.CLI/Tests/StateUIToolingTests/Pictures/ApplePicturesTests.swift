// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import AppKit
import Foundation
import StateUITooling
import XCTest

final class ApplePicturesTests: XCTestCase {
    private let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect width="20" height="10" fill="blue"/></svg>"#

    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("pictures-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    private func pixels(_ png: URL) -> (Int, Int)? {
        guard let source = CGImageSourceCreateWithURL(png as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return (image.width, image.height)
    }

    /// An SVG is drawn at a scale of its own size; a folder's SVGs become `@3x` PNGs, its other pictures are copied,
    /// and what left the folder leaves the drawn one.
    func testAFoldersSVGsAreDrawnAndItsOtherPicturesCarried() throws {
        let root = try folder()
        let images = root.appendingPathComponent("Images")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        try svg.write(to: images.appendingPathComponent("mark.svg"), atomically: true, encoding: .utf8)
        let target = root.appendingPathComponent("drawn")

        try ApplePictures.draw(images.appendingPathComponent("mark.svg"), scale: 2, to: root.appendingPathComponent("mark.png"))
        XCTAssertTrue(pixels(root.appendingPathComponent("mark.png"))! == (40, 20))

        try FileManager.default.copyItem(at: root.appendingPathComponent("mark.png"), to: images.appendingPathComponent("photo.png"))
        try Data("not a picture".utf8).write(to: images.appendingPathComponent("notes.txt"))
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data().write(to: target.appendingPathComponent("gone@3x.png"))
        try ApplePictures.draw(images, into: target)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.path).sorted(), ["mark@3x.png", "photo.png"])
        XCTAssertTrue(pixels(target.appendingPathComponent("mark@3x.png"))! == (60, 30))
    }

    /// A macOS icon set holds the ten pictures `iconutil` reads, each its own size in pixels.
    func testAnIconSetHoldsEverySizeAtOneAndTwoPixelsAPoint() throws {
        let root = try folder()
        let source = root.appendingPathComponent("icon.svg")
        try svg.write(to: source, atomically: true, encoding: .utf8)
        let iconset = root.appendingPathComponent("StateUI.iconset")

        try ApplePictures.drawIconSet(source, into: iconset)

        let names = try FileManager.default.contentsOfDirectory(atPath: iconset.path).sorted()
        XCTAssertEqual(names.count, 10)
        XCTAssertTrue(pixels(iconset.appendingPathComponent("icon_16x16.png"))! == (16, 16))
        XCTAssertTrue(pixels(iconset.appendingPathComponent("icon_512x512@2x.png"))! == (1024, 1024))
    }
}
#endif
