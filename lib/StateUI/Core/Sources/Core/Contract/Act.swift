// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One act the host can perform - one the library ships
/// (`.alert`), or an application's own registered function.
///
/// The host performs what it has a case - or a registration - for; asking for
/// anything else throws with the host's "does not perform the act" reason, which is
/// what makes a misspelled name a reported failure rather than a silence.
///
/// An application's own act shares this one flat vocabulary, and the library's
/// case is consulted first, so a registration can never shadow one of these.
/// Prefixing an application's names with its own (`"Gallery.BatteryLevel"`) is
/// what keeps the two sets from meeting at all.
public struct Act: Hashable, Sendable, CustomStringConvertible {
    /// The act's name - the library's own, or the application's registered
    /// one.
    public var name: String { key.name }

    /// The name and the number the key is worked by (`KeyName`).
    @_spi(Host) public let key: KeyName

    /// An act from its name - what a member's token is made from.
    public init(_ name: String) {
        key = KeyName(name)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}
