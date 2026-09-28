// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIUIKit
import UIKit

/// The gallery's own acts, as this host answers them.
///
/// `GalleryContract` declares each name with what it takes and answers - see
/// Sources/Samples/Interop/GalleryContract.swift - and this is the half that
/// performs them. An act aimed at a control is its view's, registered beside
/// it: `RatingBarView.register()` performs `flash`. `Gallery.Nobody` is registered nowhere on purpose: the
/// "Calling UIKit" sample calls it to show what a missing registration does.
enum GalleryActs {
    /// Registers every act this host performs. Said once, before the
    /// application runs.
    @MainActor
    static func register() {
        StateUIActs.add(GalleryContract.setClipboard) { text in
            UIPasteboard.general.string = text
        }

        StateUIActs.add(GalleryContract.readClipboard) {
            UIPasteboard.general.string ?? ""
        }

        StateUIActs.add(GalleryContract.batteryLevel) {
            battery()
        }
    }

    /// The battery's level, 0 through 1, and whether it is charging - both
    /// zero and false where UIKit knows no battery, as on the simulator, which
    /// is an ordinary answer rather than a failure.
    @MainActor
    static func battery() -> (Double, Bool) {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        guard device.batteryState != .unknown, device.batteryLevel >= 0 else { return (0, false) }

        return (Double(device.batteryLevel), device.batteryState == .charging || device.batteryState == .full)
    }
}
