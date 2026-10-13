// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// AppKit's pull-down button behind a `Button` whose click opens its menu: an arrow pointing down beside its caption,
/// the menu open at once under the press. It takes a button's caption, picture, font and whether it can be pressed.
/// Design: docs/design/platforms/appkit/views.md#a-buttons-menu
@MainActor
final class AppKitPullDownButtonView: NSPopUpButton, AppKitButtonFace, AppKitMenuOffering {
    var onPressed: (() -> Void)?
    var onReleased: (() -> Void)?
    var onClicked: (() -> Void)?
    var picture: ((HostPicture) -> NSImage?)?

    /// The keys opening the menu, which a pull-down button holds none of: its window offers them here.
    private var shortcut: KeyboardShortcut?

    /// The item a pull-down button shows its caption and picture by: first in its menu, never offered in it.
    private let face = NSMenuItem()

    init() {
        super.init(frame: .zero, pullsDown: true)
        offer([])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitPullDownButtonView is created in code")
    }

    func apply(
        text: String, image: NSImage?, imagePosition: NSControl.ImagePosition, imageScaling: NSImageScaling,
        font: NSFont, textColor: NSColor, tracking: Double, backgroundColor: NSColor?, strokeColor: NSColor?,
        lineWidth: Double, shape: ContainerShape, lineBreakMode: NSLineBreakMode, enabled: Bool
    ) {
        face.title = text
        face.image = image
        self.imagePosition = image == nil ? .noImage : imagePosition
        self.font = font
        isEnabled = enabled
        synchronizeTitleAndSelectedItem()
    }

    func applyKeys(_ shortcut: KeyboardShortcut?, role: ButtonRole?) {
        self.shortcut = shortcut
    }

    /// The menu's entries after the face, in a menu set on the button.
    func offer(_ items: [NSMenuItem]) {
        menu?.removeAllItems()
        let offered = NSMenu()
        offered.autoenablesItems = false
        offered.addItem(face)
        for item in items { offered.addItem(item) }
        menu = offered
        synchronizeTitleAndSelectedItem()
    }

    var offeredItems: [NSMenuItem] { Array((menu?.items ?? []).dropFirst()) }

    /// The window offers its key equivalents to every view: the button's keys open its menu, as a click does.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let held = event.modifierFlags.intersection([.command, .shift, .option])
        let pressed = AppKitKeys.shortcut(key: event.charactersIgnoringModifiers ?? "", modifiers: held)
        guard isEnabled, let shortcut, pressed == shortcut else { return super.performKeyEquivalent(with: event) }
        if window?.firstResponder is NSText, KeyboardShortcuts.givesWayToTyping(shortcut) { return false }
        performClick(nil)
        return true
    }

    override func mouseDown(with event: NSEvent) {
        onPressed?()
        // AppKit tracks the menu inside this call, until it closes.
        super.mouseDown(with: event)
        onReleased?()
    }
}
#endif
