// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A window of the host's, a scene's or a sheet's. The application's one monitor of keys going down sees a key
/// before AppKit dispatches it, and one a view of the window takes (`KeyboardElement.onKeyPressed`) goes no further.
/// Design: docs/design/types/keyboard.md#a-views-keys
final class AppKitWindow: NSWindow {
    var takesKey: ((_ key: String, _ modifiers: NSEvent.ModifierFlags) -> Bool)?

    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        _ = Self.keys
    }

    private static let keys: Any? = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: offered)

    /// A key going down, as the monitor is handed it: nil where a view of its window took it.
    nonisolated static func offered(_ event: NSEvent) -> NSEvent? {
        let key = event.charactersIgnoringModifiers ?? "", modifiers = event.modifierFlags, number = event.windowNumber
        let taken = MainActor.assumeIsolated {
            (NSApp.window(withWindowNumber: number) as? AppKitWindow)?.takesKey?(key, modifiers) == true
        }
        return taken ? nil : event
    }
}
#endif
