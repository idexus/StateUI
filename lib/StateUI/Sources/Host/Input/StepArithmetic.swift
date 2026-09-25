// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The arithmetic of a number the user steps: how it is written.
/// Design: docs/design/host/runtime.md#a-stepped-number
@_spi(Host) public enum StepArithmetic {
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
