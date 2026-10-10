// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import GalleryUI
import StateUIGTK

// listing: InteropEventsSample.GTK.swift
/// The gallery's own pushes, as this host raises them: the battery, as UPower tells it.
///
/// It raises on the UI thread, where GLib tells the signal, and a raise nobody hears is an ordinary answer, so the
/// source is wired whether or not anything listens.
enum GalleryEventSources {
    /// The battery as it was last said, so a notice that changed nothing of it raises nothing.
    @MainActor private static var lastSaid: (level: Double, charging: Bool)?

    /// Declares what the host raises and wires its source. Said once, before the application runs.
    @MainActor
    static func start() {
        // A handler listening for an event nothing declared is told, once, that it will not hear it.
        StateUIEvents.raises(GalleryContract.batteryChanged)

        // UPower's display device signals each change of its properties, the battery's among them.
        guard let device = GalleryPower.device else { return }
        // A C callback carries no context; the report is named in full.
        let changed: @convention(c) (OpaquePointer?, OpaquePointer?, OpaquePointer?, gpointer?) -> Void = { _, _, _, _ in
            MainActor.assumeIsolated { GalleryEventSources.report() }
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(device), "g-properties-changed", unsafeBitCast(changed, to: GCallback.self), nil,
            nil, GConnectFlags(rawValue: 0))
        report()
    }

    @MainActor
    private static func report() {
        let (level, charging) = GalleryPower.battery()
        // Nothing is raised without a battery, nor for a notice that left it as it was.
        guard level > 0, lastSaid?.level != level || lastSaid?.charging != charging else { return }

        lastSaid = (level, charging)
        StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    }
}
// listing: end
