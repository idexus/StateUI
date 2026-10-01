// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How an `ItemsView` lays its items out: one under another, one beside
/// another, or in columns as many as its width holds.
///
///     ItemsView(photos, id: \.name) { PhotoTile($0) }
///         .itemsLayout(.grid(minimumItemWidth: 120, spacing: 8))
///
/// An item is as tall as it measures in a list, as wide as it measures in a
/// row, and as wide as its column in a grid; a size stated on the item's view
/// is kept.
public enum ItemsLayout: Equatable, Sendable, HostRepresentable {
    /// One item under another, each as wide as the list, `spacing` apart.
    case list(spacing: Double = 0)

    /// One item beside another, each as tall as the row, `spacing` apart,
    /// scrolled across.
    case row(spacing: Double = 0)

    /// As many columns as fit items at least `minimumItemWidth` wide, the
    /// columns sharing the width, `spacing` apart both ways.
    case grid(minimumItemWidth: Double, spacing: Double = 0)

    /// Which of the three a layout is, as the number that crosses.
    /// Design: docs/design/types/vocabularies.md#a-kind-first
    enum Kind: Int32, Sendable {
        case list = 0
        case row = 1
        case grid = 2
    }

    /// The kind, its spacing, then its narrowest item: nought but in a grid.
    public var propValue: PropValue {
        switch self {
        case .list(let spacing):
            return .values([.enumeration(Kind.list.rawValue), .number(spacing), .number(0)])
        case .row(let spacing):
            return .values([.enumeration(Kind.row.rawValue), .number(spacing), .number(0)])
        case .grid(let width, let spacing):
            return .values([.enumeration(Kind.grid.rawValue), .number(spacing), .number(width)])
        }
    }

    /// The layout a kind and its numbers name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, parts.count == 3,
              case .enumeration(let number) = parts[0], let kind = Kind(rawValue: number),
              case .number(let spacing) = parts[1], case .number(let width) = parts[2]
        else { return nil }

        switch kind {
        case .list: self = .list(spacing: spacing)
        case .row: self = .row(spacing: spacing)
        case .grid: self = .grid(minimumItemWidth: width, spacing: spacing)
        }
    }
}
