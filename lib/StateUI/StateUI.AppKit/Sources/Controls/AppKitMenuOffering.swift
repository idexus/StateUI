// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A button offering a menu: its entries set as they stand, and read back.
@MainActor
protocol AppKitMenuOffering: NSView {
    /// Sets the menu's entries, AppKit's items for them standing on their elements.
    func offer(_ items: [NSMenuItem])

    /// The entries the menu offers now.
    var offeredItems: [NSMenuItem] { get }
}
#endif
