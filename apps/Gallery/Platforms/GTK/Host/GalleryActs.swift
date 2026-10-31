// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import GalleryUI
import StateUIGTK

// listing: InteropActsSample.GTK.swift
/// The gallery's own acts, as this host answers them.
///
/// `GalleryContract` declares each name with what it takes and answers - see
/// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
/// is its control's, registered beside it: `RatingBarWidget.register()` performs `flash`. `Gallery.Nobody` is
/// registered nowhere on purpose: the "Calling GTK" sample calls it to show what a missing registration does.
enum GalleryActs {
    /// Registers every act this host performs. Said once, before the application runs.
    @MainActor
    static func register() {
        // listing: gtk.md.acts
        // A performer is handed the arguments its act declares and answers the values it declares.
        // GLib's own log, where journalctl reads it.
        StateUIActs.add(GalleryContract.log) { line in
            g_log_default_handler("Gallery", STATEUI_LOG_LEVEL_MESSAGE, line, nil)
        }
        // listing: end
        // The battery, as UPower tells it on the system bus.
        StateUIActs.add(GalleryContract.batteryLevel) {
            GalleryPower.battery()
        }
    }
    // listing: end
}
