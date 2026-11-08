// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// listing: appkit.md.head
import GalleryUI
import StateUI
import StateUIAppKit

GalleryApp.register()
// listing: end

// listing: InteropActsSample.AppKit.swift, InteropEventsSample.AppKit.swift, appkit.md.head
// What this host answers for the application, said before it runs: the
// controls it realizes, the acts it performs, and the pushes it reports. Each
// lives in Host/ beside this file.
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()
// listing: end

// listing: appkit.md.head
AppKitHost.run()
// listing: end
