// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Network
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A watch on what Apple's platforms tell alike of the system: the user's locale and time zone, and the network -
/// each change heard on the main actor, until the watch is let go.
/// Design: docs/design/platforms/apple/system.md#the-systems-facts
@_spi(Host) @MainActor
public final class SystemWatch {
    private var observers: [NSObjectProtocol] = []
    private let network = NWPathMonitor()

    /// Watches the locale and the time zone, `localeChanged` hearing each change, and the network, `networkChanged`
    /// hearing what it reaches now - at once, then as it changes.
    public init(
        localeChanged: @escaping @MainActor () -> Void,
        networkChanged: @escaping @MainActor (HostConnectivityInfo) -> Void
    ) {
        let center = NotificationCenter.default
        for name in [NSLocale.currentLocaleDidChangeNotification, .NSSystemTimeZoneDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { localeChanged() }
            })
        }
        network.pathUpdateHandler = { path in
            MainActor.assumeIsolated { networkChanged(SystemFacts.connectivity(path)) }
        }
        network.start(queue: .main)
    }

    /// Lets go of what it watches.
    isolated deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        network.cancel()
    }
}
