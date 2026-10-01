// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIGTK
import StateUIWebViewGTK

// Register the gallery module, then say what this host answers for it before it runs: the controls it realizes,
// the acts it performs, and the pushes it reports - each in Host/ beside this file. Then hand GTK this thread until
// the last window closes.
stateui_app_register()
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()
// The backends the Gallery shows a library element through: the web view, over WebKitGTK.
StateUIWebViewGTK.register()
StateUIGTK.run(applicationID: "com.stateui.gallery")
