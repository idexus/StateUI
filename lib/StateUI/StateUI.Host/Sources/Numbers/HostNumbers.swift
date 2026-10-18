// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The numbers a host hands out for what crosses C, Java or JavaScript by number: one count across the process, so
/// no number is given twice, and one left over from a table finds nothing in another.
/// Design: docs/design/host/tree.md#held-by-number
@_spi(Host) @MainActor public enum HostNumbers {
    private static var last: Int64 = 0

    /// The next number.
    public static func next() -> Int64 {
        last += 1
        return last
    }
}
