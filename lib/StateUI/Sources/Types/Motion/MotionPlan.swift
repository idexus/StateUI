// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How each of a view's values animates: one answer, and the exceptions to it.
/// Built by `.motion(_:)` and `.motion(_:_:)`; read by the differ.
/// Design: docs/design/types/motion.md#a-plan-per-view
struct MotionPlan: Equatable, Sendable {
    /// What every value animates with, where no rule names it.
    var base: Motion?

    /// The exceptions, in writing order; the last one naming a value wins.
    var rules: [(values: MotionValues, motion: Motion)] = []

    /// How one kind of value animates, or nothing where this plan says.
    func motion(for values: MotionValues) -> Motion? {
        for rule in rules.reversed() where !rule.values.isDisjoint(with: values) {
            return rule.motion
        }

        return base
    }

    /// Compares the rules by hand: a tuple is not Equatable.
    static func == (one: MotionPlan, other: MotionPlan) -> Bool {
        one.base == other.base
            && one.rules.count == other.rules.count
            && zip(one.rules, other.rules).allSatisfy {
                $0.values == $1.values && $0.motion == $1.motion
            }
    }
}

extension MotionPlan {
    /// A view's own plan with the plan written on it over the top: the written
    /// base wins, and the written rules come later, so they win too.
    static func merged(_ made: MotionPlan?, under written: MotionPlan?) -> MotionPlan? {
        guard let written = written else { return made }
        guard let made = made else { return written }

        return MotionPlan(
            base: written.base ?? made.base,
            rules: made.rules + written.rules)
    }
}
