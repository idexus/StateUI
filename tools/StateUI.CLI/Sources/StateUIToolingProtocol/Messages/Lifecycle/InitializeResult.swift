// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the service answers `initialize` with: the API version both speak, who serves, and what it offers.
public struct InitializeResult: Codable, Equatable, Sendable {
    /// The API version the connection speaks: the newest both sides speak.
    public var apiVersion: String
    /// This service process, for the connection's life.
    public var serverInstanceId: String
    /// The tool's name and release.
    public var server: ToolIdentity
    /// The workspace served.
    public var workspace: Workspace
    /// What the service offers.
    public var capabilities: ServerCapabilities
    /// The sizes the service keeps messages within.
    public var limits: ConnectionLimits

    /// An answer to `initialize`.
    public init(
        apiVersion: String,
        serverInstanceId: String,
        server: ToolIdentity,
        workspace: Workspace,
        capabilities: ServerCapabilities,
        limits: ConnectionLimits
    ) {
        self.apiVersion = apiVersion
        self.serverInstanceId = serverInstanceId
        self.server = server
        self.workspace = workspace
        self.capabilities = capabilities
        self.limits = limits
    }
}
