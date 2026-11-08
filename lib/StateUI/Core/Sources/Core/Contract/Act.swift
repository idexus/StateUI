// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One act the host can perform - one the library ships
/// (`.alert`), or an application's own registered function.
///
/// The host performs what it has a case - or a registration - for; asking for
/// anything else throws with the host's "does not perform the act" reason, which is
/// what makes a misspelled name a reported failure rather than a silence.
///
/// An act's name is its contract's and its own (`Gallery.batteryLevel`), so an
/// application's act never meets the library's.
@_spi(Host) public struct Act: Hashable, Sendable, CustomStringConvertible {
    /// The act's name - the library's own, or the application's registered
    /// one.
    public var name: String { key.name }

    /// The act's own name, without its contract's: the name of the static member declaring it.
    @_spi(Host) public var memberName: String {
        key.name.lastIndex(of: ".").map { String(key.name[key.name.index(after: $0)...]) } ?? key.name
    }

    /// The name and the number the key is worked by (`KeyName`).
    @_spi(Host) public let key: KeyName

    /// An act from its name - what a member's token is made from.
    @_spi(Host) public init(_ name: String) {
        key = KeyName(name)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}
