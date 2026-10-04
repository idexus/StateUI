// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One semantic event a control can report, with the same stable StateUI name
/// its matching modifier uses, such as `textChanged` or `clicked`.
///
/// Comparable by name because the differ numbers a node's handlers in name
/// order, so two runs of one tree number alike.
public struct Event: Hashable, Comparable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The event's stable StateUI name.
    public let name: String

    /// An event from its name - what a member's token is made from.
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so a name reads plainly where an event is compared:
    /// `event == "clicked"`.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order - the order the differ numbers handlers in.
    public static func < (lhs: Event, rhs: Event) -> Bool {
        lhs.name < rhs.name
    }
}
