// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What the open items do once one of them has run.
public enum SwipeBehaviorOnInvoked: Int32, Sendable {
    /// Closed after a reveal, left open after an execute. The default.
    case auto = 0

    /// Always closed.
    case close = 1

    /// Always left open.
    case remainOpen = 2
}

extension SwipeBehaviorOnInvoked: HostRepresentable {}
