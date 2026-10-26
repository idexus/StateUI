// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A layout's own number for each identity its items carry: given in the order identities first appear, kept while
/// the identity stands in the layout and never given again - what a frame keys its views by, each identity compared
/// as its value once a render.
/// Design: docs/design/views/phase-layout.md#a-view-is-its-items-identity
@MainActor
final class LayoutSlotNumbers {
    private var numbers: [AnyHashable: Int] = [:]
    private var next = 0

    /// The number of each of `identities`, in order: one given before keeps it, a new one takes the next, and one no
    /// longer among them is let go.
    func numbered(_ identities: [AnyHashable]) -> [Int] {
        var kept: [AnyHashable: Int] = [:]
        kept.reserveCapacity(identities.count)
        let given = identities.map { identity in
            if let number = kept[identity] ?? numbers[identity] {
                kept[identity] = number
                return number
            }
            next += 1
            kept[identity] = next
            return next
        }
        numbers = kept
        return given
    }
}
