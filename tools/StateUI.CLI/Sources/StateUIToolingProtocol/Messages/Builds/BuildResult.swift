// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a build published, or where a package was laid: `application/build`'s and `application/package`'s result.
public struct BuildResult: Codable, Equatable, Sendable {
    /// The application's name.
    public var application: String
    public var host: HostFamily
    public var configuration: BuildConfiguration
    public var architecture: Architecture
    /// The published artifact's folder, or the package's, as a file URI.
    public var folderUri: String
    /// The program it starts by, as a file URI: a bundle's `Contents/MacOS/<Product>`.
    public var programUri: String

    /// A build of `application` laid in `folderUri`, started by `programUri`.
    public init(
        application: String, host: HostFamily, configuration: BuildConfiguration, architecture: Architecture,
        folderUri: String, programUri: String
    ) {
        self.application = application
        self.host = host
        self.configuration = configuration
        self.architecture = architecture
        self.folderUri = folderUri
        self.programUri = programUri
    }
}
