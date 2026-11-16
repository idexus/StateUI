// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Choices made: `settings/set`'s parameters. What is left out stays as it was.
public struct SettingsChange: Codable, Equatable, Sendable {
    /// A folder of the project, as a file URI; the connection's workspace when left out.
    public var projectUri: String?
    /// The application whose host and device are chosen, by name; the one the project means when left out.
    public var application: String?
    /// The application the workspace starts, by name.
    public var startup: String?
    /// The host the application is built for.
    public var host: HostFamily?
    /// The device for `host` - else for the application's chosen host - by name or id.
    public var device: String?

    /// `startup`, `host` and `device` chosen in the project at `projectUri`, for `application`.
    public init(
        projectUri: String? = nil, application: String? = nil, startup: String? = nil, host: HostFamily? = nil,
        device: String? = nil
    ) {
        self.projectUri = projectUri
        self.application = application
        self.startup = startup
        self.host = host
        self.device = device
    }
}
