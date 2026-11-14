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
    /// The program it starts by, as a file URI: an AppKit bundle's `Contents/MacOS/<Product>`, a UIKit one's
    /// `<Product>`.
    public var programUri: String
    /// The application's bundle, as a file URI: `<Product>.app`.
    public var bundleUri: String?
    /// The device or simulator a UIKit head was built for.
    public var destination: Destination?

    /// A build of `application` laid in `folderUri`, started by `programUri` of `bundleUri`, for `destination`.
    public init(
        application: String, host: HostFamily, configuration: BuildConfiguration, architecture: Architecture,
        folderUri: String, programUri: String, bundleUri: String? = nil, destination: Destination? = nil
    ) {
        self.application = application
        self.host = host
        self.configuration = configuration
        self.architecture = architecture
        self.folderUri = folderUri
        self.programUri = programUri
        self.bundleUri = bundleUri
        self.destination = destination
    }
}
