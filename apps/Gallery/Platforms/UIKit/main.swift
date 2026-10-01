// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIUIKit
import StateUIWebViewUIKit

stateui_app_register()

// What this host answers for the application, said before it runs: the
// controls it realizes, the acts it performs, and the pushes it reports. Each
// lives in Host/ beside this file.
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()
// The components the gallery shows, each realized by its UIKit backend.
StateUIWebViewUIKit.register()

StateUIUIKit.run()
