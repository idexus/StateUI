// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The kind of element a `Node` describes: a native-host capability, a
/// structural node StateUI defines, or an application's own control.
///
/// A token, not an enum, so an application's contract can name a control the
/// library has never heard of - the host draws an unknown type as a red marker
/// rather than failing, which is what keeps a lagging host visible without
/// hiding the rest of the interface.
public struct NodeType: Hashable, Comparable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible {
    /// The type's stable StateUI name, or the application's own.
    public let name: String

    /// The name's number in this process (`NameNumber`): what the key is hashed and compared by.
    private let number: Int32

    /// Whether two keys are one name.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.number == rhs.number
    }

    /// The name's number, hashed.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }

    /// A node type from its name.
    public init(_ name: String) {
        self.name = name
        number = NameNumber.of(name)
    }

    /// The literal form, which is how a contract names its node type:
    ///
    ///     static let nodeType: NodeType = "Gallery.ColorWheel"
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order, so a list of types reads sorted in a test or a dump.
    public static func < (lhs: NodeType, rhs: NodeType) -> Bool {
        lhs.name < rhs.name
    }
}
