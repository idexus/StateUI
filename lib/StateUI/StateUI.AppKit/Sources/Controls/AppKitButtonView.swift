// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native AppKit button behind StateUI's `Button` - a caption, an icon or both.
@MainActor
final class AppKitButtonView: NSButton, AppKitButtonFace {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    var onClicked: (() -> Void)?

    /// Resolves an icon's file name against the application's resources - the
    /// host's to answer, since the files and the cache over them are its.
    var picture: ((String) -> NSImage?)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        // The icon keeps beside the words, the two in the middle together, however wide the button stands.
        imageHugsTitle = true
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
        tracking: Double,
        backgroundColor: NSColor?,
        strokeColor: NSColor?,
        lineWidth: Double,
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
            attributes: [.font: font, .foregroundColor: textColor, .kern: tracking])
        self.imagePosition = image == nil ? .noImage : imagePosition
        self.imageScaling = imageScaling

        outlineShape = shape
        fill = backgroundColor
        outline = strokeColor.map { ($0, CGFloat(lineWidth)) }
        wantsLayer = backgroundColor != nil || strokeColor != nil || shape != .rectangle
        isBordered = backgroundColor == nil && strokeColor == nil
        paintBox()
    }

    /// AppKit's own key equivalent - the shortcut given - and the role's look: the accent for the main action,
    /// AppKit's mark for a destructive one.
    func applyKeys(_ shortcut: KeyboardShortcut?, role: ButtonRole?) {
        let spelled = shortcut.map(AppKitKeys.equivalent(of:)) ?? (key: "", modifiers: [])
        keyEquivalent = spelled.key
        keyEquivalentModifierMask = spelled.modifiers
        bezelColor = role == .primary ? .controlAccentColor : nil
        hasDestructiveAction = role == .destructive
    }

    /// The shape the box follows: a layer's corners round a rectangle, the button draws an oval itself.
    private var outlineShape = ContainerShape.rectangle

    /// The button's own fill, where it is given one, which the user's reach makes fainter.
    private var fill: NSColor?

    /// The button's own outline, its colour and width, where it is given one.
    private var outline: (color: NSColor, width: CGFloat)?

    /// The share of its opacity the fill keeps: all of it, less under the pointer, less still pressed.
    /// Design: docs/design/host/layout.md#a-box
    private var reach = 1.0 {
        didSet { if reach != oldValue { paintBox() } }
    }

    private var reachedFill: NSColor? {
        fill.map { $0.withAlphaComponent($0.alphaComponent * reach) }
    }

    /// Paints the box on the layer - its fill, outline and corners - or, for an oval, which a layer's corners cannot
    /// draw, asks for the button to draw it.
    private func paintBox() {
        guard let layer else { return }
        let oval = outlineShape == .ellipse
        layer.backgroundColor = oval ? nil : reachedFill?.cgColor
        layer.borderColor = oval ? nil : outline?.color.cgColor
        layer.borderWidth = oval ? 0 : outline?.width ?? 0
        layer.cornerRadius = oval ? 0 : outlineShape.cornerRadius(in: bounds)
        if oval { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        if outlineShape == .ellipse {
            let inset = (outline?.width ?? 0) / 2
            let oval = NSBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset))
            reachedFill?.setFill()
            if reachedFill != nil { oval.fill() }
            if let outline {
                outline.color.setStroke()
                oval.lineWidth = outline.width
                oval.stroke()
            }
        }
        super.draw(dirtyRect)
    }

    /// AppKit offers a key to the window's key equivalents before the view holding the keyboard: one giving way to
    /// typing is passed over while a field is being typed into, so the key types (`KeyboardShortcuts`).
    /// Design: docs/design/types/keyboard.md#a-key-typed
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder is NSText,
           let shortcut = AppKitKeys.shortcut(key: keyEquivalent, modifiers: keyEquivalentModifierMask),
           KeyboardShortcuts.givesWayToTyping(shortcut) {
            return false
        }
        return super.performKeyEquivalent(with: event)
    }

    override func layout() {
        super.layout()
        paintBox()
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
