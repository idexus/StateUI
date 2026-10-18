// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// A key: the name defining it and the number every comparison and hash works by - the name's own number, the same
/// in every process on every platform. A name is made a key once, where the key is declared, and the work is the
/// number's; keys order by name.
/// Design: docs/design/core/contracts.md#a-key-is-a-number
@_spi(Host) public struct KeyName: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// What defines the key.
    public let name: String

    /// What the key is worked by.
    let number: UInt64

    /// The key of `name`. No two names of one number are keys in one process: the second stops it.
    public init(_ name: String) {
        let number = KeyNumbers.number(of: name)
        let holder = Self.taken.withLock { $0.take(number, for: name) }
        precondition(holder == nil, "the keys `\(name)` and `\(holder ?? "")` share the number \(number)")

        self.name = name
        self.number = number
    }

    /// Whether two keys are one: their numbers are.
    public static func == (lhs: KeyName, rhs: KeyName) -> Bool {
        lhs.number == rhs.number
    }

    /// The key's number, hashed.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(number)
    }

    /// Name order, so keys sorted read alike in every process.
    public static func < (lhs: KeyName, rhs: KeyName) -> Bool {
        lhs.name < rhs.name
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Every number a key of this process holds.
    private static let taken = Mutex(KeyNumbers())
}
