// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The arithmetic of a value a control holds inside a range - a slider's, a stepper's, a bar's - the same on every
/// host: the range's ends in order, a step that moves, the share of work done, and how a stepped number is written.
/// Design: docs/design/host/runtime.md#a-value-in-a-range
@_spi(Host) public enum ValueArithmetic {
    /// The range between `minimum` and `maximum`, the lower end first, whichever the tree gave first - each end within
    /// half the reach of a 32-bit float, so the span is a number to every toolkit.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    public static func range(_ minimum: Double, _ maximum: Double) -> (lower: Double, upper: Double) {
        let held = { (end: Double) in Swift.min(Swift.max(end, -reach), reach) }
        let (minimum, maximum) = (held(minimum), held(maximum))
        return (Swift.min(minimum, maximum), Swift.max(minimum, maximum))
    }

    /// The farthest a range's end stands from nought.
    private static let reach = Double(Float.greatestFiniteMagnitude) / 2

    /// A step that moves: `step` where it is a positive number, else - none given too - 1.
    public static func step(_ step: Double?) -> Double {
        guard let step, step.isFinite, step > 0 else { return 1 }
        return step
    }

    /// The ends of the range a control of `type` stands in where the tree gives none: from 0 to a slider's 1, a
    /// share, or a stepper's 100, a count.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    public static func ends(of type: NodeType, minimum: Double?, maximum: Double?) -> (minimum: Double, maximum: Double) {
        (minimum ?? 0, maximum ?? (type == .stepper ? 100 : 1))
    }

    /// `value` held inside `lower` and `upper`: past an end it stands at that end, and a value that is no number
    /// at `lower`.
    public static func clamped(_ value: Double, lower: Double, upper: Double) -> Double {
        value.isNaN ? lower : Swift.min(Swift.max(value, lower), upper)
    }

    /// A share of work done, 0 to 1: a share past an end stands at that end, one that is no number at 0.
    public static func share(_ progress: Double) -> Double {
        progress.isFinite ? Swift.min(Swift.max(progress, 0), 1) : 0
    }

    /// The step a stepper shows where its value stands at `value` on its way to `destination`: a step of
    /// `destination`'s own - the destination and every `step` from it within `lower` and `upper` - the nearest to
    /// `value` between it and the destination, so the stepper never shows a value between two steps, one behind
    /// where the journey set out, or one past where it lands. At rest it shows its value itself.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    public static func stepped(
        _ value: Double, toward destination: Double, step: Double, lower: Double, upper: Double
    ) -> Double {
        guard destination.isFinite else { return lower }
        let held = Swift.min(Swift.max(destination, lower), upper)
        guard value.isFinite else { return held }
        let step = Self.step(step)
        let span = (value - destination) / step
        let nearest = span.rounded()
        let between = span < 0 ? Swift.max(nearest, span.rounded(.up)) : Swift.min(nearest, span.rounded(.down))
        let fewest = ((lower - destination) / step).rounded(.up), most = ((upper - destination) / step).rounded(.down)
        guard fewest <= most else { return held }
        var scale = 1.0
        for _ in 0..<decimals(of: [destination, step]) { scale *= 10 }
        return ((destination + Swift.min(Swift.max(between, fewest), most) * step) * scale).rounded() / scale
    }

    /// Which ways a stepper's step moves a `value` within `lower` and `upper`: down where it stands above the range's
    /// lower end, up where below its upper; a button whose way is at the range's end stands disabled.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    public static func stepsWay(_ value: Double, lower: Double, upper: Double) -> (down: Bool, up: Bool) {
        (value > lower, value < upper)
    }

    /// Where a stepper's one step takes `value`: a whole `step` down or up, stopping at the range's end.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    public static func step(from value: Double, up: Bool, step: Double, lower: Double, upper: Double) -> Double {
        landed(Swift.min(Swift.max(value + (up ? 1 : -1) * Self.step(step), lower), upper), from: value, step: step)
    }

    /// Where a step from `previous` by `step` lands, as a stepper reports it: `value` at the decimals of the two, where
    /// it differs from them only by what binary arithmetic adds up to - a number typed with more keeps them.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    public static func landed(_ value: Double, from previous: Double, step: Double) -> Double {
        guard value.isFinite else { return value }
        var scale = 1.0
        for _ in 0..<decimals(of: [previous, Self.step(step)]) { scale *= 10 }
        let held = (value * scale).rounded() / scale
        return abs(held - value) <= 1e-9 * Swift.max(1, abs(value)) ? held : value
    }

    /// How far a slider's thumb moves for a key and for a page: a hundredth and a tenth of its range.
    public static func sliderSteps(lower: Double, upper: Double) -> (key: Double, page: Double) {
        let span = upper - lower
        return (span / 100, span / 10)
    }

    /// How many decimals a stepped number is written with so that its step, its ends and its value all read
    /// exactly: the most any of `numbers` has, up to six; a number that is no number counts none.
    public static func decimals(of numbers: [Double]) -> Int {
        numbers.filter(\.isFinite).map { number in
            var digits = 0
            var shifted = abs(number)
            while digits < 6, abs(shifted - shifted.rounded()) > 1e-9 {
                shifted *= 10
                digits += 1
            }
            return digits
        }.max() ?? 0
    }
}
