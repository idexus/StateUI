// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// listing: uikit.md.head
import GalleryUI
import StateUIUIKit

registerApplication()
// listing: end

// listing: InteropActsSample.UIKit.swift, InteropEventsSample.UIKit.swift, uikit.md.head
// What this host answers for the application, said before it runs: the
// controls it realizes, the acts it performs, and the pushes it reports. Each
// lives in Host/ beside this file.
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()

StateUIUIKit.run()
// listing: end
