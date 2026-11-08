// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension ElementValues {
    /// The number a control of a range is written as its value and its ends apply, the same on every host: the
    /// tree's where the tree changed the value or an end - a range widened over a value the control stood clamped
    /// at shows it - else `standing`, the one the control shows, so a hand on it is never argued with.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    @MainActor
    public func written<Owner: WornContract>(
        _ value: ElementProperty<Owner, Double>, within ends: [ElementProperty<Owner, Double>], standing: Double
    ) -> Double {
        guard let tree = self[value], changed(value) || ends.contains(where: { changed($0) }) else { return standing }

        return tree
    }
}

extension ElementValues {
    /// The ends of the range the control stands in: the tree's, else its kind's (`ValueArithmetic.ends`).
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    @MainActor
    public var ends: (minimum: Double, maximum: Double) {
        ValueArithmetic.ends(
            of: Realized.nodeType, minimum: self[RangeElementContract.minimum], maximum: self[RangeElementContract.maximum])
    }
}

extension ElementValues where Realized == StepperContract {
    /// How far one of the stepper's steps moves: the tree's step where it moves, else 1.
    @MainActor
    public var step: Double { ValueArithmetic.step(self[StepperContract.step]) }

    /// The value a stepper shows - the tree's where it changed, else `standing` - as one of its steps alone: a step
    /// of where its value is headed (`ValueArithmetic.stepped`), never what a journey stands at between two.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    @MainActor
    public func shownStep(standing: Double) -> Double {
        let ends = ValueArithmetic.range(self.ends.minimum, self.ends.maximum)
        let value = written(
            RangeElementContract.value, within: [RangeElementContract.minimum, RangeElementContract.maximum], standing: standing)
        return ValueArithmetic.stepped(
            value, toward: destination(RangeElementContract.value) ?? value, step: step, lower: ends.lower, upper: ends.upper)
    }
}
