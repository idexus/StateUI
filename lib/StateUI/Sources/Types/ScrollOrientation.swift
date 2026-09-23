// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which ways a `ScrollView` scrolls.
public enum ScrollOrientation: Int32, Sendable {
    /// Up and down. The default.
    case vertical = 0

    /// Sideways.
    case horizontal = 1

    /// Both at once.
    case both = 2

    /// Neither - which is how a ScrollView is stopped from scrolling without
    /// being replaced.
    case neither = 3
}

extension ScrollOrientation: HostRepresentable {}
extension ScrollOrientation: StateChoice {}
