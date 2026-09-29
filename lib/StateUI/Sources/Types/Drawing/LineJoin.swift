// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How two segments of a line meet.
public enum LineJoin: Int32, Sendable {
    /// A sharp corner, as far out as the two edges reach. The default.
    case miter = 0

    /// The corner cut off flat.
    case bevel = 1

    /// The corner rounded.
    case round = 2
}

extension LineJoin: HostRepresentable {}
extension LineJoin: StateChoice {}
