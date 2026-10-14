// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A time zone, by its IANA name: `"Europe/Warsaw"`. The host holds the zone database, so it is the host that
/// knows a name's offsets (`TimeZoneInfo.utcOffset(of:on:)`).
///
/// Design: docs/design/types/localization.md#three-choices
public struct TimeZoneName: Hashable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    /// The IANA name.
    public let identifier: String

    /// A zone by its IANA name.
    public init(_ identifier: String) {
        self.identifier = identifier
    }

    /// A zone written as a literal: `"Europe/Warsaw"`.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The IANA name.
    public var description: String { identifier }
}
