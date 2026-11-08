// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The keys that choose an element from the keyboard while its window is in front: a button, a menu's or a
/// toolbar's item.
public enum ShortcutElementContract: Tier {
    /// The tier's own name.
    public static let name = "ShortcutElement"

    /// The keys that choose the element from the keyboard while its window is in front.
    public static let keyboardShortcut = ElementProperty<Self, KeyboardShortcut>("keyboardShortcut", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [keyboardShortcut]
}
