// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

@MainActor
final class AppKitImageViewTests: XCTestCase {
    @MainActor
    func testFillCoversAndCentresWithoutDistortingTheImage() {
        let view = AppKitImageView()
        view.frame = NSRect(x: 0, y: 0, width: 120, height: 60)
        view.apply(
            image: NSImage(size: NSSize(width: 100, height: 100)),
            aspect: .fill,
            animationPlaying: false)

        view.layoutSubtreeIfNeeded()

        XCTAssertEqual(view.renderedImageFrame.origin.x, 0, accuracy: 0.001)
        XCTAssertEqual(view.renderedImageFrame.origin.y, -30, accuracy: 0.001)
        XCTAssertEqual(view.renderedImageFrame.width, 120, accuracy: 0.001)
        XCTAssertEqual(view.renderedImageFrame.height, 120, accuracy: 0.001)
        XCTAssertEqual(view.nativeImageScaling, .scaleAxesIndependently, "over the place it covers")
    }

    @MainActor
    func testEveryAspectHasDeterministicNativeGeometry() {
        let image = NSImage(size: NSSize(width: 100, height: 50))
        let view = AppKitImageView()
        view.frame = NSRect(x: 0, y: 0, width: 60, height: 60)

        view.apply(image: image, aspect: .fit, animationPlaying: false)
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.renderedImageFrame, view.bounds)
        XCTAssertEqual(view.nativeImageScaling, .scaleProportionallyUpOrDown)

        view.apply(image: image, aspect: .stretch, animationPlaying: false)
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

        view.apply(image: image, aspect: .fit, animationPlaying: true)

        XCTAssertTrue(view.image === image)
        XCTAssertTrue(view.animationPlaying)
        XCTAssertEqual(view.intrinsicContentSize, image.size)

        view.apply(image: nil, aspect: .fit, animationPlaying: false)

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

        let renderer = testRenderer(resourceDirectory: directory, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var picture = HostPatch(id: .manual("picture"), type: .image)
        picture.properties = [
            .source: .string("picture.png"),
            .contentMode: .enumeration(ContentMode.fill.rawValue),
            .isAnimating: .bool(true),
        ]

        renderer.applyForTesting(tree(picture))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("picture")) as? AppKitImageView)
        XCTAssertNotNil(native.image)
        XCTAssertEqual(native.aspect, .fill)
        XCTAssertTrue(native.animationPlaying)
    }

    /// SVGs a second window shows cost it little: the pictures of the first window, drawn again in another, add
    /// megabytes.
    @MainActor
    func testASecondWindowShowingSVGsCostsLittle() async throws {
        stateUIUseApp(PicturesApplication())
        let renderer = testRenderer(resourceDirectory: AppKitDriver.pictures, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.startForTesting()
        Self.draw(renderer)
        let before = Self.footprint()

        try await StandardEnvironment.application.openWindow(WindowType("pictures.again"))
        renderer.runtime.pump.turn()
        Self.draw(renderer)
        let grown = Self.footprint() - before

        let pictures = renderer.windowsForTesting.compactMap(\.window?.contentView).flatMap {
            AppKitRenderer.views(AppKitImageView.self, in: $0)
        }
        XCTAssertEqual(pictures.count, 34)
        XCTAssertTrue(pictures.allSatisfy { $0.image?.size == NSSize(width: 40, height: 20) }, "the SVG, not a stand-in")
        XCTAssertLessThan(grown, 200 << 20, "the second window took \(grown >> 20) MB")
    }

    /// Every window laid out and drawn, as the display draws it.
    @MainActor
    private static func draw(_ renderer: AppKitRenderer) {
        for window in renderer.windowsForTesting.compactMap(\.window) {
            window.contentView?.layoutSubtreeIfNeeded()
            window.display()
        }
    }

    /// The memory the system counts against this process: its footprint.
    private static func footprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.phys_footprint) : 0
    }
}

/// An application whose first window shows a run of SVGs and opens a second window showing them again.
private struct PicturesApplication: Application {
    var body: some Scene { PicturesScene() }
}

private struct PicturesScene: Scene {
    var body: some Scene {
        WindowGroup { PicturesPage() }
        Window(WindowType("pictures.again")) { PicturesPage() }
    }
}

private struct PicturesPage: View {
    var body: some View {
        VStack {
            ForEach(Array(0..<17)) { _ in
                Image("test_wide.svg").width(177).height(248)
            }
        }
    }
}

#endif
