// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI

/// The gallery's own pushes, as this host raises them: the battery, as Windows tells it.
enum GalleryEventSources {
    /// The battery as it was last said, so a notice that changed nothing of it raises nothing.
    @MainActor private static var lastSaid: (level: Double, charging: Bool)?

    /// Declares what the host raises and wires its source. Said once, before the application runs.
    @MainActor
    static func start() {
        StateUIEvents.raises(GalleryContract.batteryChanged)

        gallery_battery_watch(batteryChanged)
        report()
    }

    @MainActor
    fileprivate static func report() {
        let (level, charging) = GalleryPower.battery()
        guard level > 0, lastSaid?.level != level || lastSaid?.charging != charging else { return }

        lastSaid = (level, charging)
        StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    }
}

/// What Windows calls as the battery's charge or the power source changes - on a thread of its own, and once as the
/// watch begins: the report is the main actor's.
private let batteryChanged: @convention(c) () -> Void = {
    Task { @MainActor in GalleryEventSources.report() }
}
