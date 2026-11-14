// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application built for a host: `application/build`'s parameters, and `application/package`'s with an output.
public struct BuildRequest: Codable, Equatable, Sendable {
    /// A folder of the project, as a file URI; the connection's workspace when left out.
    public var projectUri: String?
    /// The application, by name, where the project holds more than one.
    public var application: String?
    public var host: HostFamily
    /// Debug when left out; a package's, release.
    public var configuration: BuildConfiguration?
    /// The machine's own when left out.
    public var architecture: Architecture?
    /// The device or simulator a UIKit head is built for - its name, identifier or UDID; the booted simulator, else an
    /// iPhone, when left out.
    public var device: String?
    /// Where a package is laid, as a file URI; `<workspace>/artifacts/<Name>/<Host>` when left out.
    public var outputUri: String?

    /// A build of `application` of the project at `projectUri` for `host`.
    public init(
        projectUri: String? = nil, application: String? = nil, host: HostFamily, configuration: BuildConfiguration? = nil,
        architecture: Architecture? = nil, device: String? = nil, outputUri: String? = nil
    ) {
        self.projectUri = projectUri
        self.application = application
        self.host = host
        self.configuration = configuration
        self.architecture = architecture
        self.device = device
        self.outputUri = outputUri
    }
}
