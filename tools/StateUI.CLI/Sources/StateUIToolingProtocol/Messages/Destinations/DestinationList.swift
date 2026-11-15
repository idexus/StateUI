// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The host whose destinations are asked for: `devices/list`'s parameters.
public struct DestinationQuery: Codable, Equatable, Sendable {
    public var host: HostFamily

    /// The destinations of `host`.
    public init(host: HostFamily) {
        self.host = host
    }
}

/// Where a host's heads can run on this machine: `devices/list`'s result - the real devices first, then the
/// simulators, the newest system first.
public struct DestinationList: Codable, Equatable, Sendable {
    public var host: HostFamily
    public var destinations: [Destination]

    /// `host`'s `destinations`.
    public init(host: HostFamily, destinations: [Destination]) {
        self.host = host
        self.destinations = destinations
    }
}
