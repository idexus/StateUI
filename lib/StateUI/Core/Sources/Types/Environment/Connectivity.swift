// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The network, as the host last reported it. Read it as the device's
/// `connectivity`, `@Environment(\.device)`.
///
/// A host that cannot observe reachability reports `.unknown` and an empty
/// profile list.
@MainActor
public final class Connectivity {
    /// Whether the internet is reachable - `.internet` is the one worth
    /// gating a request on.
    public internal(set) var networkAccess: NetworkAccess {
        get { _networkAccess }
        set { _networkAccess = newValue }
    }

    @State private var _networkAccess: NetworkAccess = .unknown

    /// Every way the device is connected right now - Wi-Fi and cellular at
    /// once is an ordinary answer on a phone.
    public internal(set) var connectionProfiles: [ConnectionProfile] {
        get { _connectionProfiles }
        set { _connectionProfiles = newValue }
    }

    @State private var _connectionProfiles: [ConnectionProfile] = []

    /// A network as a test or a preview fakes it; what is not said starts as a headless host's does.
    public init(networkAccess: NetworkAccess = .unknown, connectionProfiles: [ConnectionProfile] = []) {
        self.networkAccess = networkAccess
        self.connectionProfiles = connectionProfiles
    }
}
