// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How much room one grid row or column takes.
///
///     Grid { … }
///         .rows(.auto, .fill, .proportional(2), .fixed(100))
///
/// Three kinds: `.auto` fits the content, `.proportional` shares what is left
/// in proportion, and `.fixed` is device units. The proportional rows are
/// settled last, out of whatever the auto and fixed rows leave.
public enum GridLength: Equatable, Sendable, HostRepresentable {
    /// As much as the content needs, and no more.
    case auto

    /// A share of what is left over, in proportion to the other shares: two
    /// columns of `.fill` and `.proportional(2)` split it one to two.
    case proportional(Double)

    /// Exactly this many device units, whatever the content measures at.
    case fixed(Double)

    /// One share of what is left - the same as `.proportional(1)`.
    public static var fill: GridLength { .proportional(1) }

    /// Which of the three kinds a length is, as the number that crosses.
    /// Design: docs/design/types/vocabularies.md#a-kind-first
    enum Kind: Int32, Sendable {
        case fixed = 0
        case proportional = 1
        case auto = 2
    }

    /// The kind, then its number; `.auto` carries 1, so every length has both
    /// parts.
    public var propValue: PropValue {
        switch self {
        case .auto:
            return .values([.enumeration(Kind.auto.rawValue), .number(1)])
        case .proportional(let share):
            return .values([.enumeration(Kind.proportional.rawValue), .number(share)])
        case .fixed(let length):
            return .values([.enumeration(Kind.fixed.rawValue), .number(length)])
        }
    }

    /// The length a kind and its number name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, parts.count == 2,
              case .enumeration(let number) = parts[0], let kind = Kind(rawValue: number),
              case .number(let amount) = parts[1]
        else { return nil }

        switch kind {
        case .auto: self = .auto
        case .proportional: self = .proportional(amount)
        case .fixed: self = .fixed(amount)
        }
    }
}
