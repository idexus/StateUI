// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which part of a state a binding borrows: every step of the road from the whole - a property, an element - so
/// `$rows[0].title` and `$rows[1].title` are two parts, and `$a.b.c` is not `$a.d.c`.
/// Design: docs/design/core/state.md#bindings
struct StatePart: Hashable, Sendable {
    private let steps: [any Hashable & Sendable]

    /// The part `step` reaches from `whole` - from the state itself where `whole` is nil.
    static func step(_ step: any Hashable & Sendable, from whole: StatePart?) -> StatePart {
        StatePart(steps: (whole?.steps ?? []) + [step])
    }

    static func == (one: StatePart, other: StatePart) -> Bool {
        guard one.steps.count == other.steps.count else { return false }

        for index in one.steps.indices where boxed(one.steps[index]) != boxed(other.steps[index]) { return false }
        return true
    }

    func hash(into hasher: inout Hasher) {
        for step in steps { hasher.combine(Self.boxed(step)) }
    }

    /// One step as a value any other compares with.
    private static func boxed<Step: Hashable>(_ step: Step) -> AnyHashable {
        AnyHashable(step)
    }
}
