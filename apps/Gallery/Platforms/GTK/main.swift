// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIGTK

// Register the gallery module, then hand GTK this thread until the last
// window closes.
stateui_app_register()
StateUIGTK.run(applicationID: "com.stateui.gallery")
