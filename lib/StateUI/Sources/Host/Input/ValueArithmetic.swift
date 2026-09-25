// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The arithmetic of a value a control holds inside a range - a slider's, a stepper's, a bar's - the same on every
/// host: the range's ends in order, a step that moves, the share of work done, and how a stepped number is written.
/// Design: docs/design/host/runtime.md#a-value-in-a-range
@_spi(Host) public enum ValueArithmetic {
    /// The range between `minimum` and `maximum`, the lower end first, whichever the tree gave first.
    public static func range(_ minimum: Double, _ maximum: Double) -> (lower: Double, upper: Double) {
        (Swift.min(minimum, maximum), Swift.max(minimum, maximum))
    }

    /// A step that moves: `step` where it is a positive number, else 1.
    public static func step(_ step: Double) -> Double {
        step.isFinite && step > 0 ? step : 1
    }

    /// A share of work done, 0 to 1: a share past an end stands at that end, one that is no number at 0.
    public static func share(_ progress: Double) -> Double {
        progress.isFinite ? Swift.min(Swift.max(progress, 0), 1) : 0
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
