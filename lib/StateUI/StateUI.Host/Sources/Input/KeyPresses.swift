// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A key pressed in a window reaching the view taking it (`View.onKeyPressed`), decided alike on every host: the
/// view holding the keyboard and those holding it, nearest first; with nothing holding the keyboard, the content of
/// the page in front and those holding it.
/// Design: docs/design/types/keyboard.md#a-views-keys
@_spi(Host) @MainActor public enum KeyPresses {
    /// The element a pressed `key` reaches, walking out from `focused` - else the content of `front`, the page in
    /// front - the first in sight and enabled taking it; nil where none does, and for a key held with the platform's
    /// own key or Alt, which is a shortcut's.
    public static func target(
        of key: Key, modifiers: KeyModifiers, focused: MountedElement?, front: MountedElement?
    ) -> MountedElement? {
        guard modifiers.isDisjoint(with: [.primary, .alt]) else { return nil }
        var each = focused ?? front.map { $0.children.first ?? $0 }
        while let element = each {
            if element.takes(key), element.standsInSight, element.isEffectivelyEnabled { return element }
            each = element.parent
        }
        return nil
    }

    /// The element holding the keyboard under `root`: the deepest that `holds` it, as its toolkit says whether a
    /// view holds the keyboard or holds the view that does; nil for none.
    public static func holder(under root: MountedElement, holds: (MountedElement) -> Bool) -> MountedElement? {
        for child in root.children {
            if let found = holder(under: child, holds: holds) { return found }
        }
        return holds(root) ? root : nil
    }

    /// Every key a press would take, walking out from `focused` - else the content of `front` - once each, in
    /// StateUI's order: what a toolkit holding its keys on the window rather than on each view offers.
    public static func taken(focused: MountedElement?, front: MountedElement?) -> [Key] {
        var keys: [Key] = []
        var each = focused ?? front.map { $0.children.first ?? $0 }
        while let element = each {
            if element.standsInSight, element.isEffectivelyEnabled {
                keys += element.value(.keysTaken).flatMap([Key].init(propValue:)) ?? []
            }
            each = element.parent
        }
        return Key.ordered(keys)
    }

    /// A pressed `key` sent to the element it reaches (`target`) as `keyPressed`; whether one took it - a host then
    /// lets the key go no further.
    @discardableResult
    public static func press(
        _ key: Key, modifiers: KeyModifiers, focused: MountedElement?, front: MountedElement?, in runtime: HostRuntime
    ) -> Bool {
        guard let target = target(of: key, modifiers: modifiers, focused: focused, front: front) else { return false }
        target.send(.keyPressed, [key.propValue], in: runtime)
        return true
    }
}

@_spi(Host) extension MountedElement {
    /// Whether the element takes `key` as it is pressed (`ViewContract.keysTaken`).
    public func takes(_ key: Key) -> Bool {
        value(.keysTaken).flatMap([Key].init(propValue:))?.contains(key) == true
    }
}
