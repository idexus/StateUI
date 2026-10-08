// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIAndroid

// listing: InteropEventsSample.Android.swift
/// The gallery's own event on this head: the battery, which the gallery's activity watches while it lives and tells
/// through GalleryNatives.
enum GalleryEventSources {
    /// Declares the event the activity's watcher raises. Said once, as the library loads.
    @MainActor
    static func register() {
        StateUIEvents.raises(GalleryContract.batteryChanged)
    }

    @MainActor private static var lastSaid: (level: Double, charging: Bool)?

    /// The battery said its level and whether it charges: raised where it changed, and a device with no battery
    /// says nothing.
    @MainActor
    static func report(level: Double, charging: Bool) {
        guard level > 0 else { return }
        guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

        lastSaid = (level, charging)
        StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    }
}
// listing: end
