// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A number that is none, which no host reads as a value.
/// Design: docs/design/core/contracts.md#a-number-that-is-none
@_spi(Host) extension PropValue {
    /// Whether the value is a number that is none - NaN, or infinite - or a run holding one.
    public var holdsNonFiniteNumber: Bool {
        switch self {
        case .number(let number): !number.isFinite
        case .numbers(let numbers): numbers.contains { !$0.isFinite }
        default: false
        }
    }
}
