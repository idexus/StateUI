// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One semantic property of a control, with the same spelling the matching
/// modifier writes.
///
/// Comparable by name because a message writes a node's properties in name
/// order - that is what makes two renders of the same tree byte-identical.
public struct Prop: Hashable, Comparable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The property's stable StateUI name.
    public let name: String

    /// A property key from its name - what a member's token is made from.
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so a name reads plainly where a key is compared:
    /// `property == "fontSize"`.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order - the order a message writes properties in.
    public static func < (lhs: Prop, rhs: Prop) -> Bool {
        lhs.name < rhs.name
    }
}
