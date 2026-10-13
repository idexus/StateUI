// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's split combo button behind a `Button` with a click of its own and a menu: its click its action, its menu
/// behind the arrow. It takes a button's caption, picture, font and whether it can be pressed; AppKit's combo button
/// takes no colour of its words, spacing between their letters or box of its own.
/// Design: docs/design/platforms/appkit/views.md#a-buttons-menu
@MainActor
final class AppKitSplitButtonView: NSComboButton, AppKitButtonFace, AppKitMenuOffering {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    var onClicked: (() -> Void)?
    var picture: ((HostPicture) -> NSImage?)?

    /// The keys pressing the button, which AppKit's combo button holds none of: its window offers them here.
    private var shortcut: KeyboardShortcut?

    init() {
        super.init(frame: .zero)
        style = .split
        target = self
        action = #selector(clicked(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitSplitButtonView is created in code")
    }

    func apply(
        text: String, image: NSImage?, imagePosition: NSControl.ImagePosition, imageScaling: NSImageScaling,
        font: NSFont, textColor: NSColor, tracking: Double, backgroundColor: NSColor?, strokeColor: NSColor?,
        lineWidth: Double, shape: ContainerShape, lineBreakMode: NSLineBreakMode, enabled: Bool
    ) {
        title = text
        self.image = image
        self.imageScaling = imageScaling
        self.font = font
        isEnabled = enabled
    }

    func applyKeys(_ shortcut: KeyboardShortcut?, role: ButtonRole?) {
        self.shortcut = shortcut
    }

    /// The menu's entries, AppKit's items for them standing on their elements, in a menu set on the button: a split
    /// button offers its arrow only for a menu set on it, never for its own one filled in place.
    /// Design: docs/design/platforms/appkit/views.md#a-buttons-menu
    func offer(_ items: [NSMenuItem]) {
        menu.removeAllItems()
        let offered = NSMenu()
        offered.autoenablesItems = false
        for item in items { offered.addItem(item) }
        menu = offered
    }

    var offeredItems: [NSMenuItem] { menu.items }

    /// The window offers its key equivalents to every view: the button's keys press it, its action, as AppKit's own
    /// button takes its key equivalent.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let held = event.modifierFlags.intersection([.command, .shift, .option])
        let pressed = AppKitKeys.shortcut(key: event.charactersIgnoringModifiers ?? "", modifiers: held)
        guard isEnabled, let shortcut, pressed == shortcut else { return super.performKeyEquivalent(with: event) }
        if window?.firstResponder is NSText, KeyboardShortcuts.givesWayToTyping(shortcut) { return false }
        clicked(self)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        onPressed?()
        // AppKit tracks the press inside this call, until the button is let go.
        super.mouseDown(with: event)
        onReleased?()
    }

    @objc private func clicked(_ sender: Any?) {
        onClicked?()
    }

    func clickForTesting() {
        onPressed?()
        clicked(self)
        onReleased?()
    }
}
#endif
