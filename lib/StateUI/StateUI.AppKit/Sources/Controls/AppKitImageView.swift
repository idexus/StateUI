// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A native image surface with the same four scaling choices on every host: fitted, stretched and centered by the
/// native view's own scaling, and covering the room where the host layer places it (`PictureArithmetic.place`),
/// which no scaling of AppKit's does.
/// Design: docs/design/host/layout.md#a-picture
@MainActor
final class AppKitImageView: AppKitHitTestView, AppKitPictureResolving {
    private let imageView = NSImageView()

    private(set) var aspect: ContentMode = .fit

    /// The picture as given; a drawing - an SVG's, a PDF's - is shown as pixels of the size it stands at.
    private(set) var image: NSImage?

    /// What the image view shows: the picture, or a drawing's pixels.
    var shownImage: NSImage? { imageView.image }

    /// The drawing the shown pixels were made of, and how many there are across and down; the ones on their way.
    private var pixelsMade: (image: NSImage, pixels: LayoutSize)?
    private var pixelsComing: (image: NSImage, pixels: LayoutSize)?

    var animationPlaying: Bool { imageView.animates }
    var renderedImageFrame: NSRect { imageView.frame }
    var nativeImageScaling: NSImageScaling { imageView.imageScaling }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        imageView.imageAlignment = .alignCenter
        // An icon, a template, stands in the words' color; any other picture draws its own.
        imageView.contentTintColor = .labelColor
        addSubview(imageView)
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitImageView is created in code")
    }

    /// Resolves a picture's file name against the application's resources -
    /// the host's to answer, since the files and the cache over them are its.
    var picture: ((HostPicture) -> NSImage?)?

    func apply(image: NSImage?, aspect: ContentMode, animationPlaying: Bool) {
        let imageChanged = self.image !== image
        self.image = image
        if imageChanged {
            pixelsMade = nil
            pixelsComing = nil
            imageView.image = image
        }
        imageView.animates = animationPlaying
        self.aspect = aspect

        if imageChanged { invalidateMeasurements() }
        needsLayout = true
    }

    /// The picture as its contract names it: a file this host resolves.
    ///
    /// A registration hands a view the values its members declare, and a file
    /// NAME is what an `ImageSource` crosses as - so resolving it belongs to
    /// the side holding the application's resources, which is why `picture` is
    /// given rather than found.
    ///
    /// - Parameters:
    ///   - source: the picture's file, or none to show nothing.
    ///   - aspect: how it fills the room it is given.
    ///   - animationPlaying: whether an animated picture runs.
    func apply(source: ImageSource?, aspect: ContentMode, animationPlaying: Bool) {
        apply(
            image: source.flatMap { HostPicture($0.propValue) }.flatMap { picture?($0) },
            aspect: aspect,
            animationPlaying: animationPlaying)
    }

    override var intrinsicContentSize: NSSize {
        image?.size ?? .zero
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        switch aspect {
        case .fit:
            imageView.imageScaling = .scaleProportionallyUpOrDown
        case .fill:
            let size = image?.size ?? .zero
            imageView.frame = NSRect(placed: PictureArithmetic.place(
                LayoutSize(width: Double(size.width), height: Double(size.height)),
                in: LayoutSize(width: Double(bounds.width), height: Double(bounds.height)), aspect: .fill))
            imageView.imageScaling = .scaleAxesIndependently
        case .stretch:
            imageView.imageScaling = .scaleAxesIndependently
        case .center:
            imageView.imageScaling = .scaleNone
        }
        showPixels()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsLayout = true
    }

    /// A drawing stands as pixels of the size it is shown at, made away from the main thread - the picture standing as
    /// it is meanwhile - and again only for more pixels, by the host layer's rule (`PictureArithmetic.vectorPixels`,
    /// `drawsAgain`): AppKit draws an image view again whenever a transform above it moves, and a drawing made anew
    /// each time, or on the main thread, drops frames.
    /// Design: docs/design/platforms/appkit/views.md#a-drawn-picture
    private func showPixels() {
        guard let image, Self.isDrawing(image) else { return }
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let room = imageView.frame.size
        let pixels = PictureArithmetic.vectorPixels(
            LayoutSize(width: Double(image.size.width), height: Double(image.size.height)),
            in: LayoutSize(width: Double(room.width), height: Double(room.height)), aspect: aspect, scale: Double(scale))
        guard pixels.width >= 1, pixels.height >= 1 else { return }
        let wanted = pixelsComing?.image === image ? pixelsComing : pixelsMade?.image === image ? pixelsMade : nil
        guard PictureArithmetic.drawsAgain(drawn: wanted?.pixels, for: pixels) else { return }

        let size = NSSize(width: pixels.width / Double(scale), height: pixels.height / Double(scale))
        pixelsComing = (image, pixels)
        let drawing = SendableDrawing(image: image)
        Task.detached(priority: .userInitiated) {
            let made = SendableDrawing(image: Self.pixels(of: drawing.image, size: size, pixels: pixels))
            await self.take(made.image, of: drawing.image, pixels: pixels)
        }
    }

    /// The pixels made for `image`, shown where they are still the ones on their way.
    private func take(_ made: NSImage?, of image: NSImage?, pixels: LayoutSize) {
        guard let made, let coming = pixelsComing, coming.image === image, coming.pixels == pixels else { return }
        pixelsComing = nil
        pixelsMade = coming
        imageView.image = made
    }

    /// Whether a picture is a file's drawing - an SVG's, a PDF's - rather than pixels; an icon - a template - AppKit
    /// tints, and one drawn by code may draw on the main thread alone: both stand as they are.
    private static func isDrawing(_ image: NSImage) -> Bool {
        !image.isTemplate && !image.representations.isEmpty
            && !image.representations.contains { $0 is NSBitmapImageRep || $0 is NSCustomImageRep }
    }

    /// `image` drawn into `pixels` across and down, standing `size` big - on any thread.
    nonisolated private static func pixels(of image: NSImage?, size: NSSize, pixels: LayoutSize) -> NSImage? {
        guard let image else { return nil }
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        bitmap.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let shown = NSImage(size: size)
        shown.addRepresentation(bitmap)
        return shown
    }
}

/// A picture handed between the main thread and the one drawing it: neither changes it.
private struct SendableDrawing: @unchecked Sendable {
    let image: NSImage?
}

#endif
