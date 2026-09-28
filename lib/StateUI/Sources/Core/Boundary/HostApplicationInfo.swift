// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Manifest facts supplied before a native host asks for its first render.
@_spi(Host) public struct HostApplicationInfo: Equatable, Sendable {
    /// The application name shown to the user.
    public let name: String

    /// The bundle or package identifier.
    public let packageName: String

    /// The user-visible release version.
    public let versionString: String

    /// The build identifier behind the release version.
    public let buildString: String

    /// A complete application report.
    public init(
        name: String,
        packageName: String,
        versionString: String,
        buildString: String
    ) {
        self.name = name
        self.packageName = packageName
        self.versionString = versionString
        self.buildString = buildString
    }
}
