// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The numbers the values written with `transitionID(_:)` and `transitionScope(_:)` cross as, so a host compares
/// numbers and never what a value says of itself. A number lives while an element wears it; one nobody wears as a
/// walk ends is forgotten, and the same value written later gets another.
/// Design: docs/design/views/transitions.md#a-shared-presentation
@MainActor
final class SharedIdentities {
    private var numbers: [AnyHashable: Int] = [:]
    private var worn: [Int: (value: AnyHashable, count: Int)] = [:]
    private var next = 1

    /// The number `value` crosses as: the one it has while anything wears it, else a new one.
    func number(for value: AnyHashable) -> Int {
        if let number = numbers[value] { return number }

        let number = next
        next += 1
        numbers[value] = number
        worn[number] = (value, 0)
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

    /// What is said of the transition id numbered `id`, in the scope numbered `scope`, worn by more than one view of
    /// one page as one of them leaves and another comes.
    func repeated(id: Int, scope: Int?) -> String {
        "the transition id \(words(id))" + (scope.map { " in scope \(words($0))" } ?? "")
            + " stands on more than one view of one page as one leaves and another comes: none takes over from "
            + "another - give each view its own transition id."
    }

    /// What is said of a view naming the scope numbered `scope` and no transition id.
    func scopeAlone(_ scope: Int) -> String {
        "a view names the transition scope \(words(scope)) and no transition id: the scope makes it one with "
            + "nothing - give it a transitionID(_:) too."
    }

    /// The value numbered `number`, quoted as the application wrote it.
    private func words(_ number: Int) -> String {
        guard let value = worn[number]?.value else { return "numbered \(number)" }
        return "\"" + ((value.base as? String) ?? String(describing: value.base)) + "\""
    }

    /// A walk ended: the numbers nobody wears are forgotten.
    func prune() {
        for (number, entry) in worn where entry.count <= 0 {
            worn[number] = nil
            numbers[entry.value] = nil
        }
    }
}
