// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import StateUI

/// A native image surface with the same four scaling choices on every host.
@MainActor
final class AppKitImageView: NSView {
    private let imageView = NSImageView()

    private(set) var aspect: Aspect = .aspectFit

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

    func apply(image: NSImage?, aspect: Aspect, animationPlaying: Bool) {
        let imageChanged = imageView.image !== image
        imageView.image = image
        imageView.animates = animationPlaying
        self.aspect = aspect

        if imageChanged { invalidateMeasurements() }
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        imageView.image?.size ?? .zero
    }

    override func layout() {
        super.layout()

        switch aspect {
        case .aspectFit:
            imageView.frame = bounds
            imageView.imageScaling = .scaleProportionallyUpOrDown

        case .aspectFill:
            imageView.frame = Self.aspectFillFrame(
                imageSize: imageView.image?.size ?? .zero,
                bounds: bounds)
            imageView.imageScaling = .scaleProportionallyUpOrDown

        case .fill:
            imageView.frame = bounds
            imageView.imageScaling = .scaleAxesIndependently

        case .center:
            imageView.frame = bounds
            imageView.imageScaling = .scaleNone
        }
    }

    private static func aspectFillFrame(imageSize: NSSize, bounds: NSRect) -> NSRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height)
    }
}

#endif
