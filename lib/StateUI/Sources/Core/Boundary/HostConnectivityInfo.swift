// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Network facts supplied by a native host, whenever the platform reports a change.
@_spi(Host) public struct HostConnectivityInfo: Equatable, Sendable {
    /// Whether the internet is reachable.
    public let networkAccess: NetworkAccess

    /// Every way the device is connected right now.
    public let connectionProfiles: [ConnectionProfile]

    /// A complete connectivity report.
    public init(networkAccess: NetworkAccess, connectionProfiles: [ConnectionProfile]) {
        self.networkAccess = networkAccess
        self.connectionProfiles = connectionProfiles
    }
}
