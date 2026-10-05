// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

/// The gallery's own acts, as this host answers them: through the page's own scripts, Page/gallery-acts.js, which
/// reach the browser's clipboard and battery.
///
/// `GalleryContract` declares each name with what it takes and answers - see
/// Sources/Samples/Interop/GalleryContract.swift - and this is the half that performs them. An act aimed at a control
/// is its control's, registered beside it: `RatingBarElement.register()` performs `flash`. `Gallery.Nobody` is
/// registered nowhere on purpose: the "Calling Web" sample calls it to show what a missing registration does.
enum GalleryActs {
    /// Registers every act this host performs. Said once, before the application runs.
    @MainActor
    static func register() {
        StateUIActs.add(GalleryContract.setClipboard) { text in
            _ = try await StateUIScripts.call("setClipboard", text)
        }
        StateUIActs.add(GalleryContract.readClipboard) {
            try await StateUIScripts.call("readClipboard")
        }
        StateUIActs.add(GalleryContract.batteryLevel) {
            battery(try await StateUIScripts.call("batteryLevel"))
        }
    }

    /// The battery as the page's scripts say it - its level from 0 to 1 and whether it charges, two words - 0 where
    /// they say nothing of it.
    static func battery(_ words: String) -> (Double, Bool) {
        let said = words.split(separator: " ")
        return (said.first.flatMap { Double($0) } ?? 0, said.count > 1 && said[1] == "true")
    }
}
