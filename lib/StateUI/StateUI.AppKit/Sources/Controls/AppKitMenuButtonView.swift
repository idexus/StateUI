// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's combo button behind a `Button` holding a menu: unified, its click opening the menu, or split, its click
/// its own action and its menu behind the arrow. It takes a button's caption, picture, font and whether it can be
/// pressed; AppKit's combo button takes no colour of its words, spacing between their letters or box of its own.
/// Design: docs/design/views/controls.md#a-buttons-menu
@MainActor
final class AppKitMenuButtonView: NSComboButton, AppKitButtonFace {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    var onClicked: (() -> Void)?
    var picture: ((String) -> NSImage?)?

    /// The keys pressing the button, which AppKit's combo button holds none of: its window offers them here.
    private var shortcut: KeyboardShortcut?

    init(splits: Bool) {
        super.init(frame: .zero)
        style = splits ? .split : .unified
        target = self
        action = #selector(clicked(_:))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitMenuButtonView is created in code")
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

    /// The menu's entries, AppKit's items for them standing on their elements.
    func offer(_ items: [NSMenuItem]) {
        menu.autoenablesItems = false
        menu.removeAllItems()
        for item in items { menu.addItem(item) }
    }

    /// The window offers its key equivalents to every view: the button's keys press it - its action where it splits,
    /// its menu where a click opens one - as AppKit's own button takes its key equivalent.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let held = event.modifierFlags.intersection([.command, .shift, .option])
        let pressed = AppKitKeys.shortcut(key: event.charactersIgnoringModifiers ?? "", modifiers: held)
        guard isEnabled, let shortcut, pressed == shortcut else { return super.performKeyEquivalent(with: event) }
        if window?.firstResponder is NSText, KeyboardShortcuts.givesWayToTyping(shortcut) { return false }
        if style == .split {
            clicked(self)
        } else {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 4), in: self)
        }
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
