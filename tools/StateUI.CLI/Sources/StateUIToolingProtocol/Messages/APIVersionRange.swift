// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The minor versions of one major version of the tooling API a program speaks.
///
/// A minor version only adds; a major version may change what a message means.
public struct APIVersionRange: Codable, Equatable, Sendable {
    /// The major version.
    public var major: Int
    /// The oldest minor version spoken.
    public var minMinor: Int
    /// The newest minor version spoken.
    public var maxMinor: Int

    /// The minor versions `minMinor` through `maxMinor` of `major`.
    public init(major: Int, minMinor: Int, maxMinor: Int) {
        self.major = major
        self.minMinor = minMinor
        self.maxMinor = maxMinor
    }

    /// The newest version of the range as a message names it, such as `1.0`.
    public var newest: String { "\(major).\(maxMinor)" }
}
