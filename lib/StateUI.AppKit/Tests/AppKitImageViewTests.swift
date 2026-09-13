// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitImageViewTests: XCTestCase {
    @MainActor
    func testAspectFillCoversAndCentersWithoutDistortingTheImage() {
        let view = AppKitImageView()
        view.frame = NSRect(x: 0, y: 0, width: 120, height: 60)
        view.apply(
            image: NSImage(size: NSSize(width: 100, height: 100)),
            aspect: .aspectFill,
            animationPlaying: false)

        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.renderedImageFrame.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(view.renderedImageFrame.origin.y, -30, accuracy: 0.001)
        XCTAssertEqual(view.renderedImageFrame.width, 120, accuracy: 0.001)
        XCTAssertEqual(view.renderedImageFrame.height, 120, accuracy: 0.001)
        XCTAssertEqual(view.nativeImageScaling, .scaleProportionallyUpOrDown)
    }

    @MainActor
    func testEveryAspectHasDeterministicNativeGeometry() {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        let view = AppKitImageView()
        view.frame = NSRect(x: 0, y: 0, width: 60, height: 60)

        view.apply(image: image, aspect: .aspectFit, animationPlaying: false)
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.renderedImageFrame, view.bounds)
        XCTAssertEqual(view.nativeImageScaling, .scaleProportionallyUpOrDown)

        view.apply(image: image, aspect: .fill, animationPlaying: false)
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.renderedImageFrame, view.bounds)
        XCTAssertEqual(view.nativeImageScaling, .scaleAxesIndependently)

        view.apply(image: image, aspect: .center, animationPlaying: false)
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.renderedImageFrame, view.bounds)
        XCTAssertEqual(view.nativeImageScaling, .scaleNone)
    }

    @MainActor
    func testAnimationStateAndIntrinsicSizeFollowTheImage() {
        let image = NSImage(size: NSSize(width: 42, height: 24))
        let view = AppKitImageView()

        view.apply(image: image, aspect: .aspectFit, animationPlaying: true)

        XCTAssertTrue(view.image === image)
        XCTAssertTrue(view.animationPlaying)
        XCTAssertEqual(view.intrinsicContentSize, image.size)

        view.apply(image: nil, aspect: .aspectFit, animationPlaying: false)

        XCTAssertNil(view.image)
        XCTAssertFalse(view.animationPlaying)
        XCTAssertEqual(view.intrinsicContentSize, .zero)
    }

    @MainActor
    func testHostPatchMapsSourceAspectAndAnimation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0))
        let blue = NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
        bitmap.setColor(blue, atX: 0, y: 0)
        bitmap.setColor(blue, atX: 1, y: 0)
        let representation = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try representation.write(to: directory.appendingPathComponent("picture.png"))

        let renderer = AppKitRenderer(resourceDirectory: directory, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var picture = HostPatch(id: .manual("picture"), type: .image)
        picture.properties = [
            .source: .string("picture.png"),
            .aspect: .enumeration(Aspect.aspectFill.rawValue),
            .isAnimationPlaying: .bool(true),
        ]

        renderer.applyForTesting(tree(picture))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("picture")) as? AppKitImageView)
        XCTAssertNotNil(native.image)
        XCTAssertEqual(native.aspect, .aspectFill)
        XCTAssertTrue(native.animationPlaying)
    }
}

#endif
