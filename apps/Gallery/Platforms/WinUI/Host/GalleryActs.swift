// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGalleryWinUI
import GalleryUI
import StateUIWinUI
import WinSDK

// listing: InteropActsSample.WinUI.swift
/// The gallery's own acts, as this host answers them.
///
/// `GalleryContract` declares each name with what it takes and answers - see
/// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
/// is its control's, registered beside it: `RatingBarControl.register()` performs `flash`. `Gallery.Nobody` is
/// registered nowhere on purpose: the "Calling WinUI" sample calls it to show what a missing registration does.
enum GalleryActs {
    /// Registers every act this host performs. Said once, before the application runs.
    @MainActor
    static func register() {
        // The log needs no relay: Swift calls Win32 itself - OutputDebugStringW, which a debugger reads.
        StateUIActs.add(GalleryContract.log) { line in
            line.withCString(encodedAs: UTF16.self) { OutputDebugStringW($0) }
        }
        // The power status, GetSystemPowerStatus, read by the gallery's relay.
        StateUIActs.add(GalleryContract.batteryLevel) {
            GalleryPower.battery()
        }
    }
}
// listing: end

/// The battery as Windows knows it, which the gallery's relay reads.
enum GalleryPower {
    /// The battery's level, 0 through 1, and whether the power is plugged in - both zero and false on a desktop that
    /// has no battery to report, which is an ordinary answer rather than a failure.
    static func battery() -> (Double, Bool) {
        var level = 0.0
        var charging = false
        gallery_battery(&level, &charging)
        return (level, charging)
    }
}
