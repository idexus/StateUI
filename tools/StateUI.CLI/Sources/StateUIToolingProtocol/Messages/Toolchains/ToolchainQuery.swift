// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What `toolchain/check` checks: this machine - or, where `device` names a guest of it, that guest, for the host's
/// heads and the project in `projectUri`.
public struct ToolchainQuery: Codable, Equatable, Sendable {
    public var host: HostFamily?
    /// A guest a head of `host` is built in: its name, as `devices/list` gives it.
    public var device: String?
    /// The project whose application and checkout the guest is to reach.
    public var projectUri: String?

    /// A check of this machine, unless `device` names a guest.
    public init(host: HostFamily? = nil, device: String? = nil, projectUri: String? = nil) {
        self.host = host
        self.device = device
        self.projectUri = projectUri
    }
}
