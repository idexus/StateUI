// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a `Button` is on AppKit whichever control stands for it - a button, or a combo button holding its menu: the
/// three moments of a press, its look, and the keys pressing it.
@MainActor
protocol AppKitButtonFace: AppKitPictureResolving {
    var onPressed: (() -> Void)? { get set }
    var onReleased: (() -> Void)? { get set }
    var onClicked: (() -> Void)? { get set }

    /// The button's caption, picture and look.
    func apply(
        text: String, image: NSImage?, imagePosition: NSControl.ImagePosition, imageScaling: NSImageScaling,
        font: NSFont, textColor: NSColor, tracking: Double, backgroundColor: NSColor?, strokeColor: NSColor?,
        lineWidth: Double, shape: ContainerShape, lineBreakMode: NSLineBreakMode, enabled: Bool)

    /// The keys pressing the button - the one it states, else its role's - and its role's look.
    func applyKeys(_ shortcut: KeyboardShortcut?, role: ButtonRole?)
}
#endif
