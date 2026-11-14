// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A built application installed where its host shows it, never built again: `application/install`'s parameters.
public struct InstallRequest: Codable, Equatable, Sendable {
    /// The artifact a build published, as a file URI of its folder.
    public var artifactUri: String

    /// An install of the artifact at `artifactUri`.
    public init(artifactUri: String) {
        self.artifactUri = artifactUri
    }
}

/// What an install wrote: `application/install`'s result.
public struct InstallResult: Codable, Equatable, Sendable {
    public var artifactUri: String
    /// The files it wrote, as file URIs: a GTK head's desktop entry and icon.
    public var writtenUris: [String]

    /// The install of `artifactUri`, having written `writtenUris`.
    public init(artifactUri: String, writtenUris: [String]) {
        self.artifactUri = artifactUri
        self.writtenUris = writtenUris
    }
}
