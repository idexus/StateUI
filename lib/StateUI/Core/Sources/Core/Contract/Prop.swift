// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One semantic property of a control, with the same spelling the matching
/// modifier writes.
///
/// Comparable by name because the differ walks a node's driven and cleared
/// properties in name order - that is what makes two renders of one tree alike.
public struct Prop: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The property's stable StateUI name.
    public var name: String { key.name }

    /// The name and the number the key is worked by (`KeyName`).
    @_spi(Host) public let key: KeyName

    /// A property key from its name - what a member's token is made from.
    public init(_ name: String) {
        key = KeyName(name)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order - the order the differ walks properties in.
    public static func < (lhs: Prop, rhs: Prop) -> Bool {
        lhs.key < rhs.key
    }
}
