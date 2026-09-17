// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// The native AppKit button behind StateUI's `Button` - a caption, an icon or both.
@MainActor
final class AppKitButtonView: NSButton, AppKitPictureResolving {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    var onClicked: (() -> Void)?

    /// Resolves an icon's file name against the application's resources - the
    /// host's to answer, since the files and the cache over them are its.
    var picture: ((String) -> NSImage?)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        target = self
        action = #selector(clicked(_:))
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitButtonView is created in code")
    }

    func apply(
        text: String,
        image: NSImage?,
        imagePosition: NSControl.ImagePosition,
        imageScaling: NSImageScaling,
        font: NSFont,
        textColor: NSColor,
        backgroundColor: NSColor?,
        borderColor: NSColor?,
        borderWidth: Double,
        cornerRadius: Double,
        lineBreakMode: NSLineBreakMode,
        enabled: Bool
    ) {
        title = text
        self.image = image
        self.font = font
        isEnabled = enabled
        cell?.lineBreakMode = lineBreakMode
        attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: textColor])
        self.imagePosition = image == nil ? .noImage : imagePosition
        self.imageScaling = imageScaling

        wantsLayer = backgroundColor != nil || borderColor != nil
            || borderWidth > 0 || cornerRadius > 0
        layer?.backgroundColor = backgroundColor?.cgColor
        layer?.borderColor = borderColor?.cgColor
        layer?.borderWidth = max(0, borderWidth)
        layer?.cornerRadius = max(0, cornerRadius)
        isBordered = backgroundColor == nil && borderColor == nil && borderWidth <= 0
    }

    override func mouseDown(with event: NSEvent) {
        onPressed?()
        super.mouseDown(with: event)
        onReleased?()
    }

    @objc private func clicked(_ sender: NSButton) {
        onClicked?()
    }

    func clickForTesting() {
        onPressed?()
        clicked(self)
        onReleased?()
    }
}

#endif
