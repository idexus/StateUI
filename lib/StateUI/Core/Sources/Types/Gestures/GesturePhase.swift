// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How far along a continuous gesture is.
public enum GesturePhase: Int32, Sendable {
    /// The gesture has begun. A platform that reports no beginning starts with
    /// `.changed`, so a handler reads each report's values rather than relying
    /// on this one.
    case began = 0

    /// The gesture is under way, and this is where it has got to.
    case changed = 1

    /// The pointer or fingers have been lifted.
    case ended = 2

    /// The platform took the gesture away - a call arriving, a scroll winning.
    case cancelled = 3
}

extension GesturePhase: HostRepresentable {}
