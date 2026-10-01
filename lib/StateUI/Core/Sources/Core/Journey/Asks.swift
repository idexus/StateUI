// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/journeys.md#readings

/// How often a reading is taken - the cadence of
/// `.samples($fade, into: $shown, .every(100))`. A state itself has no cadence;
/// two views may read one value at two rates.
public enum Asks: Equatable, Sendable {
    /// A reading on every frame the host writes.
    case always

    /// A reading at most once every so many milliseconds: the first frame in a
    /// window at once, the last when the window ends. The window is not a delay a
    /// render waits out. Nought or less is `.always`.
    case every(Int)

    /// How long a reading may be held back, in milliseconds.
    var window: Int {
        switch self {
        case .always: return 0
        case .every(let milliseconds): return max(0, milliseconds)
        }
    }
}
