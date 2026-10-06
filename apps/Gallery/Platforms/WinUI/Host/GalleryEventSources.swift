// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI

// listing: InteropEventsSample.WinUI.swift
/// The gallery's own pushes, as this host raises them: the battery, as Windows tells it.
enum GalleryEventSources {
    /// The battery as it was last said, so a notice that changed nothing of it raises nothing.
    @MainActor private static var lastSaid: (level: Double, charging: Bool)?

    /// Declares what the host raises and wires its source. Said once, before the application runs.
    @MainActor
    static func start() {
        // A handler listening for an event nothing declared is told, once, that it will not hear it.
        StateUIEvents.raises(GalleryContract.batteryChanged)

        // The gallery's relay asks Windows for each change of the battery's charge and of the power source
        // (PowerSettingRegisterNotification). A raise nobody hears is an ordinary answer, so it is wired regardless.
        gallery_battery_watch(batteryChanged)
        report()
    }

    @MainActor
    fileprivate static func report() {
        let (level, charging) = GalleryPower.battery()
        // Windows tells more than a level change: no battery, or a reading unchanged, raises nothing.
        guard level > 0, lastSaid?.level != level || lastSaid?.charging != charging else { return }

        lastSaid = (level, charging)
        StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    }
}

/// What Windows calls as the battery's charge or the power source changes - on a thread of its own, and once as the
/// watch begins: the report is the main actor's.
/// It stands outside the main actor, as a closure written inside `start()` would be the main actor's.
private let batteryChanged: @convention(c) () -> Void = {
    Task { @MainActor in GalleryEventSources.report() }
}
// listing: end
