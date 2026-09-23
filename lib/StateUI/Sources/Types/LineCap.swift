// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How the end of an open line is drawn.
public enum LineCap: Int32, Sendable {
    /// Cut off square at the end point. The default.
    case flat = 0

    /// A half-circle beyond the end point, so the line looks rounded off.
    case round = 1

    /// A square beyond the end point - the same shape as `.flat`, half a stroke
    /// further along.
    case square = 2
}

extension LineCap: HostRepresentable {}
extension LineCap: StateChoice {}
