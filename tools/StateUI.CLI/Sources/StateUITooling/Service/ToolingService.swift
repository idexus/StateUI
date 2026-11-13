// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol

/// The work every client of the tool asks for, by the tooling API's methods: the terminal's commands and an
/// editor's JSON-RPC requests both call it.
public struct ToolingService: Sendable {
    /// A service for this process.
    public init() {}

    /// The tool's name, release, API versions and machine - `server/info`.
    public func serverInfo() -> ServerInfo {
        ServerInfo(
            server: ToolIdentity(name: "stateui", version: Release.version),
            apiVersions: Release.apiVersions,
            machine: .current
        )
    }
}
