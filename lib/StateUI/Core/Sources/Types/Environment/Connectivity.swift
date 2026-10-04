// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The network, as the host last reported it. Read it as the device's
/// `connectivity`, `@Environment(\.device)`.
///
/// A host that cannot observe reachability reports `.unknown` and an empty
/// profile list.
public final class Connectivity {
    /// Whether the internet is reachable - `.internet` is the one worth
    /// gating a request on.
    @State public var networkAccess: NetworkAccess = .unknown

    /// Every way the device is connected right now - Wi-Fi and cellular at
    /// once is an ordinary answer on a phone.
    @State public var connectionProfiles: [ConnectionProfile] = []

    /// A fresh instance, its values starting as a headless host's do.
    public init() {}
}
