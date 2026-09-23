// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What one dot of a PositionIndicator is drawn as.
public enum IndicatorShape: Int32, Sendable {
    /// A dot. The default.
    case circle = 0

    /// A square.
    case square = 1
}

extension IndicatorShape: HostRepresentable {}
extension IndicatorShape: StateChoice {}
