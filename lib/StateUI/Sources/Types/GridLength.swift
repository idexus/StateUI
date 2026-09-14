// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How much room each row and column of a grid takes.

/// How much room one grid row or column takes.
///
///     Grid { … }
///         .rows(.auto, .fill, .proportional(2), .fixed(100))
///
/// Three kinds: `.auto` fits the content, `.fill` shares what is left in
/// proportion, and `.absolute` is device-independent units. The stars are
/// settled last, out of whatever the auto and absolute rows leave.
///
/// It travels as the two PARTS it is - which kind, then the number that kind
/// takes - and a list of them as a list of those.
public enum GridLength: Sendable {
    /// As much as the content needs, and no more.
    case auto

    /// A share of what is left over, in proportion to the other stars: two
    /// columns of `.fill` and `.proportional(2)` split it one to two.
    case proportional(Double)

    /// Exactly this many device units, whatever the content measures at.
    case fixed(Double)

    /// One share of what is left - the same as `.proportional(1)`.
    public static var fill: GridLength { .proportional(1) }

    /// Which of the three kinds a length is, as the number that crosses - a
    /// closed vocabulary, so it rides its member rather than a spelling. The
    /// numbers are this library's own: see the head of Types/Enums.swift.
    enum Kind: Int32, Sendable {
        case fixed = 0
        case proportional = 1
        case auto = 2
    }

    /// The kind, then the number that kind takes.
    ///
    /// `.auto` carries a 1 rather than nothing, so every length crosses as the
    /// same two parts - a kind and a number - and a host reads each one the
    /// same way.
    var propValue: PropValue {
        switch self {
        case .auto:
            return .values([.enumeration(Kind.auto.rawValue), .number(1)])
        case .proportional(let share):
            return .values([.enumeration(Kind.proportional.rawValue), .number(share)])
        case .fixed(let length):
            return .values([.enumeration(Kind.fixed.rawValue), .number(length)])
        }
    }
}

extension Array where Element == GridLength {
    /// The definitions, each as its own two parts - so the LIST itself says
    /// how many rows or columns there are.
    var propValue: PropValue {
        .values(map { $0.propValue })
    }
}
