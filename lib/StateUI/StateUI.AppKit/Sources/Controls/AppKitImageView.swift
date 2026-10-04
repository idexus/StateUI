// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A native image surface with the same four scaling choices on every host: fitted, stretched and centred by the
/// native view's own scaling, and covering the room where the host layer places it (`PictureArithmetic.place`),
/// which no scaling of AppKit's does.
/// Design: docs/design/host/layout.md#a-picture
@MainActor
final class AppKitImageView: AppKitHitTestView, AppKitPictureResolving {
    private let imageView = NSImageView()

    private(set) var aspect: ContentMode = .fit

    var image: NSImage? { imageView.image }
    var animationPlaying: Bool { imageView.animates }
    var renderedImageFrame: NSRect { imageView.frame }
    var nativeImageScaling: NSImageScaling { imageView.imageScaling }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        imageView.imageAlignment = .alignCenter
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
    var picture: ((String) -> NSImage?)?

    func apply(image: NSImage?, aspect: ContentMode, animationPlaying: Bool) {
        let imageChanged = imageView.image !== image
        imageView.image = image
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
            image: source.flatMap { $0.isEmpty ? nil : picture?($0.file) },
            aspect: aspect,
            animationPlaying: animationPlaying)
    }

    override var intrinsicContentSize: NSSize {
        imageView.image?.size ?? .zero
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        switch aspect {
        case .fit:
            imageView.imageScaling = .scaleProportionallyUpOrDown
        case .fill:
            let size = imageView.image?.size ?? .zero
            imageView.frame = NSRect(placed: PictureArithmetic.place(
                LayoutSize(width: Double(size.width), height: Double(size.height)),
                in: LayoutSize(width: Double(bounds.width), height: Double(bounds.height)), aspect: .fill))
            imageView.imageScaling = .scaleAxesIndependently
        case .stretch:
            imageView.imageScaling = .scaleAxesIndependently
        case .center:
            imageView.imageScaling = .scaleNone
        }
    }
}

#endif
