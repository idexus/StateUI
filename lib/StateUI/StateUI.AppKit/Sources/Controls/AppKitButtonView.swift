// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native AppKit button behind StateUI's `Button` - a caption, an icon or both - and, holding a menu, the menu it
/// opens: by its click, an arrow pointing down after its words; by a split button's arrow part; or held, no arrow.
/// AppKit's own menu buttons take no box or colour of their words, so a button holding a menu is this one too.
/// Design: docs/design/platforms/appkit/views.md#a-buttons-menu
@MainActor
final class AppKitButtonView: NSButton, AppKitPictureResolving {
    override class var cellClass: AnyClass? {
        get { AppKitButtonCell.self }
        set {}
    }

    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    var onClicked: (() -> Void)?

    /// Resolves an icon's file name against the application's resources - the
    /// host's to answer, since the files and the cache over them are its.
    var picture: ((HostPicture) -> NSImage?)?

    /// How the button opens its menu, which it is made for; none for a button holding no menu.
    let opening: ButtonMenuOpening

    /// The menu the button offers, its entries as they stand.
    private let offered = NSMenu()

    /// The arrow its menu opens by: a mark after the words, or a split button's part; nil for none.
    private var arrow: AppKitButtonArrow?

    /// How long a held button waits before it opens its menu, in seconds.
    private static let holdDelay = 0.5

    /// A button opening its menu as `opening` says, showing the arrow after its words where its click opens it and
    /// `showsArrow`.
    init(menu opening: ButtonMenuOpening = .none, showsArrow: Bool = false) {
        self.opening = opening
        super.init(frame: .zero)
        bezelStyle = .push
        // The icon keeps beside the words, the two in the middle together, however wide the button stands.
        imageHugsTitle = true
        target = self
        action = #selector(clicked(_:))
        offered.autoenablesItems = false
        if opening == .arrow {
            arrow = .part(in: self)
        } else if opening == .click, showsArrow {
            arrow = .mark(in: self)
        }
        (cell as? AppKitButtonCell)?.arrowRoom = arrow?.room ?? 0
    }

    /// A button holding no menu, standing in `frame`.
    convenience override init(frame frameRect: NSRect) {
        self.init(menu: .none, showsArrow: false)
        frame = frameRect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitButtonView is created in code")
    }

    /// `image` as the button shows it: an icon - a template - in `colour` where its words stand in one of their own,
    /// which a bordered button's tint leaves in the platform's; any other picture as it is.
    /// Design: docs/design/host/layout.md#an-icon
    private static func picture(_ image: NSImage?, in colour: NSColor) -> NSImage? {
        guard let image, image.isTemplate, colour != .controlTextColor else { return image }
        return NSImage(size: image.size, flipped: false) { room in
            image.draw(in: room)
            colour.set()
            room.fill(using: .sourceAtop)
            return true
        }
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
        self.image = Self.picture(image, in: textColor)
        self.font = font
        isEnabled = enabled
        cell?.lineBreakMode = lineBreakMode
        attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: textColor, .kern: tracking])
        arrow?.tint(textColor)
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

    /// The height of AppKit's push button, above which a button stands in the flexible push button's bezel.
    private static let pushHeight: CGFloat = {
        let reference = NSButton(title: "Push", target: nil, action: nil)
        reference.bezelStyle = .push
        return reference.fittingSize.height
    }()

    /// The bezel stands as tall as the button: the push button's at its own height, the flexible push button's -
    /// AppKit's push button of any height - where the button stands taller.
    /// Design: docs/design/platforms/appkit/views.md#a-buttons-padding
    private func standBezel() {
        let style: NSButton.BezelStyle = bounds.height > Self.pushHeight + 0.5 ? .flexiblePush : .push
        if bezelStyle != style { bezelStyle = style }
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

    /// The whole of the view under a transform, which AppKit leaves out of what it takes for visible.
    override var visibleRect: NSRect { drawnRect(visible: super.visibleRect) }

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
        standBezel()
        paintBox()
        guard let arrow, let cell else { return }
        let words = cell.titleRect(forBounds: bounds)
        let wordsWidth = title.isEmpty ? 0 : attributedTitle.size().width
        var content = NSRect(x: words.midX - wordsWidth / 2, y: words.minY, width: wordsWidth, height: words.height)
        if image != nil {
            let picture = cell.imageRect(forBounds: bounds)
            content = title.isEmpty ? picture : content.union(picture)
        }
        arrow.place(in: bounds, after: content, rightToLeft: userInterfaceLayoutDirection == .rightToLeft)
    }

    /// The button's own size and the room it keeps for its arrow.
    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        size.width += arrow?.room ?? 0
        return size
    }

    /// Sets the menu's entries, AppKit's items for them standing on their elements.
    func offer(_ items: [NSMenuItem]) {
        offered.removeAllItems()
        for item in items { offered.addItem(item) }
    }

    /// The entries the menu offers now.
    var offeredItems: [NSMenuItem] { offered.items }

    /// Whether the button shows the arrow saying its click opens its menu.
    var showsMenuMark: Bool { arrow.map { $0.line == nil } ?? false }

    /// Opens the menu under the button, at least as wide, as AppKit's own pull-down button opens its.
    func showMenu() {
        offered.minimumWidth = bounds.width
        offered.popUp(positioning: nil, at: NSPoint(x: 0, y: isFlipped ? bounds.maxY + 2 : bounds.minY - 2), in: self)
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
        switch opening {
        // The menu opens as the button is pressed, and stays pressed while it is open.
        case .click: pressed(showMenu)
        case .hold: held()
        // AppKit tracks the press inside this call, until the button is let go.
        case .none, .arrow: super.mouseDown(with: event)
        }
        let inside = window.map { bounds.contains(convert($0.mouseLocationOutsideOfEventStream, from: nil)) } ?? false
        reach = inside ? PressedFill.underPointer : 1
        onReleased?()
    }

    /// Draws the button pressed while `action` runs.
    private func pressed(_ action: () -> Void) {
        highlight(true)
        action()
        highlight(false)
    }

    /// A held button: let go before the hold's delay, its click; held past it, its menu opens, the press going on
    /// into it. AppKit's own tracking reads the press's events.
    private func held() {
        guard let window else { return }
        let until = Date(timeIntervalSinceNow: Self.holdDelay)
        pressed {
            var letGo: NSEvent?
            while letGo == nil,
                  let next = window.nextEvent(
                    matching: [.leftMouseUp, .leftMouseDragged], until: until, inMode: .eventTracking, dequeue: true) {
                if next.type == .leftMouseUp { letGo = next }
            }
            guard let letGo else { return showMenu() }
            if bounds.contains(convert(letGo.locationInWindow, from: nil)) { onClicked?() }
        }
    }

    /// A click, the keyboard's or assistive technology's press: the button's action, or its menu where its click
    /// opens it.
    @objc private func clicked(_ sender: NSButton) {
        if opening == .click { showMenu() } else { onClicked?() }
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
