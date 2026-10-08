// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIUIKit
import UIKit

// listing: InteropEventsSample.UIKit.swift
/// The gallery's own pushes: what this host reports without being asked.
///
/// `GalleryContract` declares each event with what it carries, and every
/// `HostEvents.on` subscription hears it. A raise nobody hears is an ordinary
/// answer, so the sources are wired unconditionally.
///
/// THE SPLIT IS THE PLATFORM'S: a device UIKit knows no battery of - the
/// simulator - reports nothing at all, and the sample's own words say so.
/// What is watched here is the battery, which UIKit reports through the
/// notification centre once its monitoring is on.
@MainActor
enum GalleryEventSources {
// listing: end
    /// What was last said, so an unchanged reading raises nothing.
    private static var lastSaid: (level: Double, charging: Bool)?

    private static var observers: [NSObjectProtocol] = []

    // listing: InteropEventsSample.UIKit.swift
    /// Declares what the gallery raises and starts watching. Said once,
    /// before the application runs.
    static func start() {
        // What the host raises, declared where its source is wired: a handler
        // listening for an event nothing raises is told so.
        StateUIEvents.raises(GalleryContract.batteryChanged)

        UIDevice.current.isBatteryMonitoringEnabled = true
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { report() }
            })
        }
        report()
    }

    /// Raises the battery's reading, where it has changed and there is one.
    private static func report() {
        let (level, charging) = GalleryActs.battery()

        guard level > 0 else { return }
        guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

        lastSaid = (level, charging)
        StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    }
}
// listing: end
