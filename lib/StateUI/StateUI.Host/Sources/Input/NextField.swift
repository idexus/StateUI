// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The keyboard handed on from a field whose return says Next (`SubmitLabel.next`) to the field after it in the order
/// its page reads, decided alike on every host.
/// Design: docs/design/types/keyboard.md#the-next-field
@_spi(Host) @MainActor public enum NextField {
    /// The fields the keyboard is handed on to: what the user types in.
    public static let fieldTypes: Set<NodeType> = [.textField, .searchField, .textEditor]

    /// The field `field` hands the keyboard on to as it is submitted, where its return says Next: the first after it
    /// on its page, in the order the page is written - a page inside it read by none but itself - in sight and
    /// enabled; nil where its return says no Next, and past the last.
    public static func after(_ field: MountedElement) -> MountedElement? {
        guard field.value(.submitLabel).flatMap(SubmitLabel.init(propValue:)) == .next else { return nil }
        var page = field
        while page.type != .page, let parent = page.parent { page = parent }
        var passed = false
        return first(under: page) { each in
            if each === field {
                passed = true
                return false
            }
            return passed && fieldTypes.contains(each.type) && each.standsInSight && each.isEffectivelyEnabled
        }
    }

    /// The first element under `element`, depth first, `meets` says yes to; no page inside it is read.
    private static func first(under element: MountedElement, meeting meets: (MountedElement) -> Bool)
        -> MountedElement?
    {
        for child in element.children where child.type != .page {
            if meets(child) { return child }
            if let found = first(under: child, meeting: meets) { return found }
        }
        return nil
    }
}
