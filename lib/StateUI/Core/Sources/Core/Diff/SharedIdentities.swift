// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The numbers the identities written by hand with `.id()` cross as, so a host compares numbers and never what
/// a value says of itself. A number lives while an element wears it; one nobody wears as
/// a walk ends is forgotten, and the same identity written later gets another.
/// Design: docs/design/views/transitions.md#a-shared-presentation
@MainActor
final class SharedIdentities {
    private var numbers: [ElementIdentity: Int] = [:]
    private var worn: [Int: (identity: ElementIdentity, count: Int)] = [:]
    private var next = 1

    /// The number `identity` crosses as: the one it has while anything wears it, else a new one.
    func number(for identity: ElementIdentity) -> Int {
        if let number = numbers[identity] { return number }

        let number = next
        next += 1
        numbers[identity] = number
        worn[number] = (identity, 0)
        return number
    }

    /// An element came to wear `number`.
    func wear(_ number: Int) {
        worn[number]?.count += 1
    }

    /// An element wearing `number` left, or wears another.
    func unwear(_ number: Int) {
        worn[number]?.count -= 1
    }

    /// What is said of `number` worn by more than one view of one page as one of them leaves and another comes.
    func repeated(_ number: Int) -> String {
        let named = worn[number].map { "the id \"\(Node.described($0.identity))\"" } ?? "the id numbered \(number)"
        return "\(named) stands on more than one view of one page as one leaves and another comes: none takes over "
            + "from another - give each view its own id."
    }

    /// A walk ended: the numbers nobody wears are forgotten.
    func prune() {
        for (number, entry) in worn where entry.count <= 0 {
            worn[number] = nil
            numbers[entry.identity] = nil
        }
    }
}
