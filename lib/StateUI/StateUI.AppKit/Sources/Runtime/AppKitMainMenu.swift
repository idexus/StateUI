// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The menu bar. AppKit offers it a key before the view holding the keyboard: a key giving way to typing is passed
/// over while a field is being typed into, so the key types there (`KeyboardShortcuts`).
/// Design: docs/design/types/keyboard.md#a-key-typed
final class AppKitMainMenu: NSMenu {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers ?? "", modifiers = event.modifierFlags, number = event.windowNumber
        let typed = MainActor.assumeIsolated {
            (NSApp.window(withWindowNumber: number) ?? NSApp.keyWindow)?.firstResponder is NSText
                && AppKitKeys.shortcut(key: key, modifiers: modifiers).map(KeyboardShortcuts.givesWayToTyping) == true
        }
        return !typed && super.performKeyEquivalent(with: event)
    }
}
#endif
