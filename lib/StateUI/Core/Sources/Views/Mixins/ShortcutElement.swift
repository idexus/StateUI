// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element chosen from the keyboard shares - a button, a menu's or a toolbar's item: the keys that choose it.
///
///     Button("Save").keyboardShortcut("s")
///     MenuItem("Copy").keyboardShortcut("c")
public protocol ShortcutElement: PropertyContainer {}

extension ShortcutElement {
    /// Keys that choose the element from the keyboard while its window is in
    /// front: `key` with `modifiers` - the platform's Command or Control unless
    /// said otherwise. A button, a bar's item and a menu bar's entry are chosen
    /// by them; a context menu's entry shows them beside its words.
    ///
    ///     Button("Send").keyboardShortcut(.return, modifiers: [])
    ///     ToolbarButton("Share").keyboardShortcut("s", modifiers: [.primary, .shift])
    public func keyboardShortcut(_ key: Key, modifiers: KeyModifiers = .primary) -> Modified {
        setValue(ShortcutElementContract.keyboardShortcut, KeyboardShortcut(key, modifiers: modifiers))
    }
}
