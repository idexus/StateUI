// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIApple
import XCTest

/// A drawing that takes as long as a test says: it says when it has begun, and ends when it is told to.
private final class SlowDrawing: NSImageRep, @unchecked Sendable {
    let begun = DispatchSemaphore(value: 0)
    let done = DispatchSemaphore(value: 0)

    override init() {
        super.init()
        size = NSSize(width: 40, height: 20)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(in rect: NSRect) -> Bool {
        begun.signal()
        _ = done.wait(timeout: .now() + 5)
        return true
    }
}

@MainActor
final class AppKitImageViewTests: XCTestCase {
    @MainActor
    func testFillCoversAndCentersWithoutDistortingTheImage() {
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

    /// A DRAWN PICTURE STANDS AS PIXELS OF THE SIZE IT IS SHOWN AT: AppKit draws an image view again whenever a
    /// transform above it moves, and an SVG drawn anew each time cost a turning light table 300 ms of every 500. As
    /// pixels a draw costs nothing; made away from the main thread, they are made again only for more pixels, by the
    /// host layer's rule.
    func testADrawnPictureStandsAsPixelsOfTheSizeItIsShownAt() throws {
        let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect width="100" height="50" fill="red"/></svg>"#
        let drawing = try XCTUnwrap(NSImage(data: Data(svg.utf8)))
        let view = AppKitImageView()
        view.frame = NSRect(x: 0, y: 0, width: 60, height: 60)
        view.apply(image: drawing, aspect: .fill, animationPlaying: false)
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.shownImage === drawing, "the drawing as it is, until its pixels come")

        let shown = try pixels(of: view)
        let bitmap = try XCTUnwrap(shown.representations.first as? NSBitmapImageRep)
        XCTAssertEqual(shown.size, view.renderedImageFrame.size, "pixels of the size it covers")
        XCTAssertGreaterThanOrEqual(bitmap.pixelsWide, 120, "a pixel a point at the least")
        XCTAssertTrue(view.image === drawing, "the picture as given")
        XCTAssertEqual(view.intrinsicContentSize, drawing.size)

        view.frame = NSRect(x: 0, y: 0, width: 50, height: 50)
        view.layoutSubtreeIfNeeded()
        pump()
        XCTAssertTrue(view.shownImage === shown, "fewer pixels draw nothing again")

        view.frame = NSRect(x: 0, y: 0, width: 200, height: 200)
        view.layoutSubtreeIfNeeded()
        let grown = try pixels(of: view, other: shown)
        XCTAssertEqual(grown.size, NSSize(width: 400, height: 200), "more pixels, drawn again")
    }

    /// A drawing's pixels being made keep no view that left the tree meanwhile: the work holds the drawing, and the
    /// view is let go as its owner lets it go, however long the drawing takes; the pixels come to nobody.
    func testADrawingsPixelsBeingMadeKeepNoViewThatLeft() async throws {
        let drawing = NSImage(size: NSSize(width: 40, height: 20))
        let slow = SlowDrawing()
        drawing.addRepresentation(slow)
        XCTAssertTrue(drawing.isDrawing)
        weak var gone: AppKitImageView?
        autoreleasepool {
            let view = AppKitImageView()
            gone = view
            view.frame = NSRect(x: 0, y: 0, width: 40, height: 20)
            view.apply(image: drawing, aspect: .fit, animationPlaying: false)
            view.layoutSubtreeIfNeeded()
        }
        defer { slow.done.signal() }
        XCTAssertTrue(begun(slow), "the drawing is being made")
        XCTAssertNil(gone, "the view, let go by its owner, is gone while its drawing is still being made")
    }

    /// Whether `drawing` has begun within two seconds - waited for apart from any task, as a semaphore is.
    nonisolated private func begun(_ drawing: SlowDrawing) -> Bool {
        drawing.begun.wait(timeout: .now() + 2) == .success
    }

    /// The pixels the view shows once they come, other than `other`.
    private func pixels(of view: AppKitImageView, other: NSImage? = nil) throws -> NSImage {
        let deadline = Date(timeIntervalSinceNow: 2)
        while Date() < deadline {
            if let shown = view.shownImage, shown !== other, shown.representations.first is NSBitmapImageRep { return shown }
            pump()
        }
        return try XCTUnwrap(nil as NSImage?, "no pixels came")
    }

    /// A turn of the main run loop, where what the background made is taken.
    private func pump() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
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

    /// A picture is made once for the renderer, whatever it is: an icon or bytes handed again is the image already
    /// shown, so a bar, a tab row or a card handed the same picture finds nothing changed.
    @MainActor
    func testEveryPictureIsMadeOnce() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.finish() }
        let dot = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let bytes = try XCTUnwrap(dot.representation(using: .png, properties: [:]))

        for picture in [HostPicture.icon(.add), .bytes(Array(bytes))] {
            let first = try XCTUnwrap(renderer.image(picture))
            XCTAssertTrue(renderer.image(picture) === first, "\(picture) made again")
        }
        XCTAssertFalse(renderer.image(.icon(.add)) === renderer.image(.icon(.remove)), "each icon its own")
    }

    /// A picture something still shows is the same picture asked for again, even after the system let the
    /// renderer's cache go under memory pressure: a view handed it again finds nothing changed.
    @MainActor
    func testAPictureStillShownOutlastsTheCache() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.finish() }
        let shown = try XCTUnwrap(renderer.image(.icon(.add)))

        renderer.pictures.letGoOfKept()

        XCTAssertTrue(renderer.image(.icon(.add)) === shown, "made again while shown")
    }

    /// Of the pictures nothing shows, the latest asked for are kept while their pixels stay within the budget; the
    /// one asked for longest ago goes first, and is made again when asked for.
    @MainActor
    func testPicturesNothingShowsAreKeptWithinTheBudget() throws {
        let cache = PictureCache<NSImage>(budget: 4, pixels: { $0.pixels })
        var made: [String] = []
        func ask(_ name: String) {
            _ = cache.image(.file(name)) {
                made.append(name)
                let pixels = NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 1, bitsPerSample: 8, samplesPerPixel: 4,
                    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                let image = NSImage(size: NSSize(width: 2, height: 1))
                pixels.map(image.addRepresentation)
                return image
            }
        }

        autoreleasepool { for name in ["a", "b", "c"] { ask(name) } }
        autoreleasepool { for name in ["c", "b", "a"] { ask(name) } }

        XCTAssertEqual(made, ["a", "b", "c", "a"], "six pixels asked for, four kept: a went first")
    }

    @MainActor
    /// A name the application has no file for resolves to nothing, as on every host: no picture stands in.
    func testANameWithNoFileResolvesToNothing() {
        let renderer = testRenderer(resourceDirectory: FileManager.default.temporaryDirectory, presentsWindows: false)
        defer { renderer.finish() }

        XCTAssertNil(renderer.image(named: "no-such-picture-\(UUID().uuidString)"))
    }

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
        defer { renderer.finish() }
        var picture = HostPatch(id: .manual("picture"), type: .image)
        picture.properties = [
            ImageContract.source.token: .string("picture.png"),
            .contentMode: .enumeration(ContentMode.fill.rawValue),
            ImageContract.isAnimating.token: .bool(true),
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
        PicturesApplication.register()
        let renderer = testRenderer(resourceDirectory: AppKitDriver.pictures, presentsWindows: false)
        defer { renderer.finish() }
        renderer.startForTesting()
        Self.draw(renderer)
        let before = Self.footprint()

        try await StandardEnvironment.application.openWindow(WindowKind("pictures.again"))
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

    /// A drawing keeps no pixels of the sizes it was drawn at: the picture stays found while anything shows it, and
    /// each image view holds its own pixels of the size it shows.
    @MainActor
    func testADrawingKeepsNoPixelsOfTheSizesItWasDrawnAt() throws {
        let renderer = testRenderer(resourceDirectory: AppKitDriver.pictures, presentsWindows: false)
        defer { renderer.finish() }
        let drawing = try XCTUnwrap(renderer.image(named: "test_wide.svg"))
        let before = Self.footprint()

        autoreleasepool {
            for side in stride(from: 1000, through: 1700, by: 100) {
                var room = NSRect(x: 0, y: 0, width: side, height: side)
                _ = drawing.cgImage(forProposedRect: &room, context: nil, hints: nil)
            }
        }

        let kept = Self.footprint() - before
        XCTAssertLessThan(kept, 64 << 20, "the drawing kept \(kept >> 20) MB")
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

    /// An icon standing alone is drawn in the words' color, as the label beside it is.
    func testAnIconIsDrawnInTheWordsColor() throws {
        let renderer = AppKitRenderer.running {
            HStack {
                Image(.icon(.share)).width(24).height(24)
                Text("Share")
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { renderer.finish() }
        renderer.windowsForTesting.first?.window?.contentView?.layoutSubtreeIfNeeded()
        let icon = try inkColor(of: XCTUnwrap(renderer.nativeViews(AppKitImageView.self).first))
        let words = try inkColor(of: XCTUnwrap(renderer.nativeViews(AppKitTextView.self).first))

        XCTAssertTrue(sameInk(icon, words), "the icon's \(String(describing: icon)), the words' \(String(describing: words))")
    }
}

/// An application whose first window shows a run of SVGs and opens a second window showing them again.
private struct PicturesApplication: Application {
    var body: some Scene { PicturesScene() }
}

private struct PicturesScene: Scene {
    var body: some Scene {
        WindowGroup { PicturesPage() }
        Window(WindowKind("pictures.again")) { PicturesPage() }
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
