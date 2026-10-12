// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A window's keyboard shortcuts, read alike on every host: what states one, the element a shortcut pressed acts on,
/// and a shortcut stated twice.
/// Design: docs/design/types/keyboard.md#in-a-window
@_spi(Host) @MainActor public enum KeyboardShortcuts {
    /// What a shortcut acts on: a button, a bar's item, or an entry of a menu bar - never a context menu's entry,
    /// whose shortcut the platform only shows beside it.
    public static func acts(_ element: MountedElement) -> Bool {
        switch element.type {
        case .button, .toolbarItem: true
        case .menuItem: element.enclosing(type: .contextMenu) == nil
        default: false
        }
    }

    /// The elements under `root` stating `shortcut` that it acts on, standing in sight, in reading order.
    public static func stating(_ shortcut: KeyboardShortcut, under root: MountedElement) -> [MountedElement] {
        actors(under: root).filter { $0.keyboardShortcut == shortcut }
    }

    /// The element under `root` a pressed `shortcut` acts on: the first in reading order stating it, standing in
    /// sight and enabled; nil where none does.
    public static func target(of shortcut: KeyboardShortcut, under root: MountedElement) -> MountedElement? {
        stating(shortcut, under: root).first { $0.isEffectivelyEnabled }
    }

    /// Whether `shortcut` gives way to typing: a character's key held with neither the platform's own key nor Alt -
    /// alone, or with Shift - is the character a field holding the keyboard writes, not a shortcut there.
    public static func givesWayToTyping(_ shortcut: KeyboardShortcut) -> Bool {
        shortcut.key.character != nil && shortcut.modifiers.isDisjoint(with: [.primary, .alt])
    }

    /// Every shortcut the elements in sight under `root` state, once each, in reading order - those giving way to
    /// typing left out while a field holds the keyboard (`typing`): what a window offers a toolkit holding its
    /// shortcuts on the window rather than on each control.
    public static func stated(under root: MountedElement, typing: Bool = false) -> [KeyboardShortcut] {
        var found: [KeyboardShortcut] = []
        for shortcut in actors(under: root).compactMap(\.keyboardShortcut) where !found.contains(shortcut) {
            if typing, givesWayToTyping(shortcut) { continue }
            found.append(shortcut)
        }
        return found
    }

    /// A pressed `shortcut` reaching the element under `root` it acts on: a button clicked, an item chosen
    /// (`MountedElement.chosen`) - unless it gives way to typing while a field holds the keyboard (`typing`).
    /// Whether one took it.
    @discardableResult
    public static func press(
        _ shortcut: KeyboardShortcut, under root: MountedElement, in runtime: HostRuntime, typing: Bool = false
    ) -> Bool {
        if typing, givesWayToTyping(shortcut) { return false }
        guard let target = target(of: shortcut, under: root) else { return false }
        if target.type == .button { target.send(.clicked, [], in: runtime) } else { target.chosen(in: runtime) }
        return true
    }

    /// Every shortcut more than one element in sight under `root` states, in reading order of its first.
    public static func repeated(under root: MountedElement) -> [KeyboardShortcut] {
        var seen: [KeyboardShortcut] = []
        var twice: [KeyboardShortcut] = []
        for shortcut in actors(under: root).compactMap(\.keyboardShortcut) {
            if seen.contains(shortcut) {
                if !twice.contains(shortcut) { twice.append(shortcut) }
            } else {
                seen.append(shortcut)
            }
        }
        return twice
    }

    /// Says, once a process, each shortcut stated twice in sight under `root`: which of them acts is then not the
    /// application's choice.
    public static func complainOfRepeats(under root: MountedElement) {
        for shortcut in repeated(under: root) {
            Complaints.say("The keyboard shortcut \(shortcut) is stated twice in one window: one of them acts.")
        }
    }

    /// Says each shortcut stated twice in a window of the tree under `root`, where `patch` states, changes or takes
    /// away a shortcut anywhere in it.
    public static func complainOfRepeats(in root: MountedElement, after patch: HostPatch) {
        guard touched(by: patch) else { return }
        for window in root.windows.isEmpty ? [root] : root.windows { complainOfRepeats(under: window) }
    }

    private static func touched(by patch: HostPatch) -> Bool {
        patch.properties[.keyboardShortcut] != nil || patch.clearedProperties.contains(.keyboardShortcut)
            || patch.children.contains(where: touched(by:))
    }

    private static func actors(under root: MountedElement) -> [MountedElement] {
        var found: [MountedElement] = []
        func walk(_ element: MountedElement) {
            if acts(element), element.keyboardShortcut != nil, element.standsInSight { found.append(element) }
            element.children.forEach(walk)
        }
        walk(root)
        return found
    }
}

@_spi(Host) extension MountedElement {
    /// The shortcut this element states; nil for none.
    public var keyboardShortcut: KeyboardShortcut? {
        value(.keyboardShortcut).flatMap(KeyboardShortcut.init(propValue:))
    }

    /// Whether the element stands where the user meets it: it and everything holding it shown, on the page each
    /// arrangement around it shows - a stack's top, the chosen tab, the sheet over the others.
    public var standsInSight: Bool {
        guard standsShown else { return false }
        var child = self
        while let parent = child.parent {
            guard parent.standsShown else { return false }
            switch parent.type {
            case .navigationStack, .modalStack: if parent.children.last !== child { return false }
            case .tabView: if let chosen = parent.selectedTab, chosen !== child { return false }
            default: break
            }
            child = parent
        }
        return true
    }
}
