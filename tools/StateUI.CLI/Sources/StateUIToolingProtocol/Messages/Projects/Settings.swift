// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What was chosen on this machine, out of git: the workspace's application to start, and the application's host and
/// each host's device - `settings/get`'s and `settings/set`'s result.
public struct Settings: Codable, Equatable, Sendable {
    /// The workspace's folder, as a file URI; none where the project stands in none.
    public var workspaceUri: String?
    /// The application the workspace starts, by name.
    public var startup: String?
    /// The application's folder, as a file URI; none where the project means none.
    public var applicationUri: String?
    /// The host the application is built for.
    public var host: HostFamily?
    /// The device chosen for each host, by the host's name.
    public var devices: [String: String]

    /// Choices: the workspace's `startup`, the application's `host` and `devices`.
    public init(
        workspaceUri: String? = nil, startup: String? = nil, applicationUri: String? = nil, host: HostFamily? = nil,
        devices: [String: String] = [:]
    ) {
        self.workspaceUri = workspaceUri
        self.startup = startup
        self.applicationUri = applicationUri
        self.host = host
        self.devices = devices
    }
}
