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
        strokeColor: NSColor?,
        strokeWidth: Double,
        shape: AppKitDecoration.Shape,
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

        outlineShape = shape
        let shaped: Bool = if case .rectangle = shape { false } else { true }
        wantsLayer = backgroundColor != nil || strokeColor != nil || shaped
        layer?.backgroundColor = backgroundColor?.cgColor
        layer?.borderColor = strokeColor?.cgColor
        layer?.borderWidth = strokeColor == nil ? 0 : max(0, strokeWidth)
        roundCorners()
        isBordered = backgroundColor == nil && strokeColor == nil
    }

    /// The shape the corners follow - an oval rounded into a capsule, which is what a layer's corners can draw.
    private var outlineShape = AppKitDecoration.Shape.rectangle

    private func roundCorners() {
        switch outlineShape {
        case .rectangle: layer?.cornerRadius = 0
        case .rounded(let radius): layer?.cornerRadius = radius
        case .ellipse: layer?.cornerRadius = min(bounds.width, bounds.height) / 2
        }
    }

    override func layout() {
        super.layout()
        roundCorners()
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
