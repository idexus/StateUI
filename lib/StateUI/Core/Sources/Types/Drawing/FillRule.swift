// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which parts of a self-crossing outline count as inside it.
public enum FillRule: Int32, Sendable {
    /// Inside where a ray out of the shape crosses an odd number of edges - so
    /// the middle of a five-pointed star is a hole. The default.
    case evenOdd = 0

    /// Inside where the edges crossed do not cancel out by direction - so the
    /// middle of a star is filled.
    case nonzero = 1
}

extension FillRule: HostRepresentable {}
extension FillRule: StateChoice {}
