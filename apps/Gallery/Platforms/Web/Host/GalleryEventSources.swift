// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

// listing: InteropEventsSample.Web.swift
/// The gallery's own pushes, as this host raises them: the battery, as the browser tells the page's scripts.
enum GalleryEventSources {
    /// Declares what the host raises and wires its source. Said once, before the application runs.
    @MainActor
    static func start() {
        // What the host raises, declared where its source is wired: a handler listening for an event nothing
        // declared is told, once, that it will not hear it.
        StateUIEvents.raises(GalleryContract.batteryChanged)
        StateUIScripts.hear("battery") { words in
            let (level, charging) = GalleryActs.battery(words)
            guard level > 0 else { return }
            StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
        }
    }
}
// listing: end
