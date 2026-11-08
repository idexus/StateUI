// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One semantic event a control can report, with the same stable StateUI name
/// its matching modifier uses, such as `textChanged` or `clicked`.
///
/// Comparable by name because the differ numbers a node's handlers in name
/// order, so two runs of one tree number alike.
@_spi(Host) public struct Event: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// The event's stable StateUI name.
    public var name: String { key.name }

    /// The event's own name, without its contract's: the name of the static member declaring it.
    @_spi(Host) public var memberName: String {
        key.name.lastIndex(of: ".").map { String(key.name[key.name.index(after: $0)...]) } ?? key.name
    }

    /// The name and the number the key is worked by (`KeyName`).
    @_spi(Host) public let key: KeyName

    /// An event from its name - what a member's token is made from.
    @_spi(Host) public init(_ name: String) {
        key = KeyName(name)
    }

    /// The event key a member already holds, made again from nothing.
    init(key: KeyName) {
        self.key = key
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order - the order the differ numbers handlers in.
    public static func < (lhs: Event, rhs: Event) -> Bool {
        lhs.key < rhs.key
    }
}
