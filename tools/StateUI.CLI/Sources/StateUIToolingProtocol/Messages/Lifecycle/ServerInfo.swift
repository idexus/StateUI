// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the tool says of itself: its name and release, the API versions it speaks and the machine it runs on.
///
/// The result of `stateui version` and of the `server/info` method.
public struct ServerInfo: Codable, Equatable, Sendable {
    /// The tool's name and release.
    public var server: ToolIdentity
    /// The API versions the tool speaks, a range of minor versions for each major.
    public var apiVersions: [APIVersionRange]
    /// The machine the tool runs on.
    public var machine: Machine
    /// The hosts this machine builds and runs heads of, in the matrix's order, each with where its heads run.
    public var hosts: [HostPlace]

    /// The information a tool gives of itself.
    public init(server: ToolIdentity, apiVersions: [APIVersionRange], machine: Machine, hosts: [HostPlace]) {
        self.server = server
        self.apiVersions = apiVersions
        self.machine = machine
        self.hosts = hosts
    }
}
