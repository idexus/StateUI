// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import AppKit
import GalleryUI
import IOKit.ps
import os
import StateUIAppKit

// listing: InteropActsSample.AppKit.swift
/// The gallery's own acts, as this host answers them.
///
/// `GalleryContract` declares each name with what it takes and answers - see
/// Sources/Samples/Interop/GalleryContract.swift - and this is the half that
/// performs them. An act aimed at a control is its view's, registered beside
/// it: `RatingBarView.register()` performs `flash`. `Gallery.Nobody` is registered nowhere on purpose: the
/// "Calling AppKit" sample calls it to show what a missing registration does.
enum GalleryActs {
    /// Registers every act this host performs. Said once, before the
    /// application runs.
    @MainActor
    static func register() {
        // listing: appkit.md.acts
        // A performer is handed the arguments its act declares and answers
        // the values it declares.
        StateUIActs.add(GalleryContract.log) { line in
            Logger(subsystem: "com.stateui.gallery", category: "Gallery").notice("\(line, privacy: .public)")
        }

        StateUIActs.add(GalleryContract.batteryLevel) {
            battery()
        }
        // listing: end
    }
    // listing: end

    /// The battery's level, 0 through 1, and whether it is charging - both
    /// zero and false on a desktop that has no battery to report, which is an
    /// ordinary answer rather than a failure.
    static func battery() -> (Double, Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return (0, false) }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                let maximum = description[kIOPSMaxCapacityKey] as? Int,
                maximum > 0
            else { continue }

            let charging = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return (Double(capacity) / Double(maximum), charging)
        }

        return (0, false)
    }
    // listing: InteropActsSample.AppKit.swift
}
// listing: end
