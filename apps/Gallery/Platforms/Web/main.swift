// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

// Register the application module, then say what this host realizes for it -
// the controls in Host/ beside this file, their elements in Page/ - and show it
// in the page; the browser calls it from then on.
stateui_app_register()
GalleryControls.register()
StateUIWeb.run(name: "Gallery")
