// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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
        shape: ContainerShape,
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
        fill = backgroundColor
        wantsLayer = backgroundColor != nil || strokeColor != nil || shape != .rectangle
        paintFill()
        layer?.borderColor = strokeColor?.cgColor
        layer?.borderWidth = strokeColor == nil ? 0 : strokeWidth
        if let layer { shape.round(layer) }
        isBordered = backgroundColor == nil && strokeColor == nil
    }

    /// The shape the corners follow - an oval rounded into a capsule, which is what a layer's corners can draw.
    private var outlineShape = ContainerShape.rectangle

    /// The button's own fill, where it is given one, which the user's reach makes fainter.
    private var fill: NSColor?

    /// The share of its opacity the fill keeps: all of it, less under the pointer, less still pressed.
    /// Design: docs/design/host/layout.md#a-box
    private var reach = 1.0 {
        didSet { if reach != oldValue { paintFill() } }
    }

    private func paintFill() {
        layer?.backgroundColor = fill.map { $0.withAlphaComponent($0.alphaComponent * reach).cgColor }
    }

    override func layout() {
        super.layout()
        if let layer { outlineShape.round(layer) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        reach = PressedFill.underPointer
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        reach = 1
    }

    override func mouseDown(with event: NSEvent) {
        onPressed?()
        reach = PressedFill.pressed
        // AppKit tracks the press inside this call, until the button is let go.
        super.mouseDown(with: event)
        let inside = window.map { bounds.contains(convert($0.mouseLocationOutsideOfEventStream, from: nil)) } ?? false
        reach = inside ? PressedFill.underPointer : 1
        onReleased?()
    }

    @objc private func clicked(_ sender: NSButton) {
        onClicked?()
    }

    /// The share of its opacity the fill keeps now.
    var reachForTesting: Double { reach }

    func clickForTesting() {
        onPressed?()
        clicked(self)
        onReleased?()
    }
}

#endif
