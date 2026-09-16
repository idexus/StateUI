// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import GalleryUI
import IOKit.ps
import StateUIAppKit

/// The gallery's own pushes: what this host reports without being asked.
///
/// `GalleryContract` declares each event with what it carries, and every
/// `HostEvents.on` subscription hears it. A raise nobody hears is an ordinary
/// answer, so the sources are wired unconditionally.
///
/// THE SPLIT IS THE PLATFORM'S: a desktop with no battery reports nothing at
/// all, and the sample's own words say so. What is watched here is the power
/// source, which macOS reports through a run-loop source of its own.
enum GalleryEventSources {
    /// What was last said, so an unchanged reading raises nothing - a power
    /// source notifies on far more than a level change.
    nonisolated(unsafe) private static var lastSaid: (level: Double, charging: Bool)?

    /// Starts watching. Said once, before the application runs.
    static func start() {
        // Named in full: a C function pointer carries no context at all, and
        // an unqualified call to a static method captures the type implicitly.
        let notify: IOPowerSourceCallbackType = { _ in GalleryEventSources.report() }

        guard let source = IOPSNotificationCreateRunLoopSource(notify, nil)?.takeRetainedValue()
        else { return }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
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
