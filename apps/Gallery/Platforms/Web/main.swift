// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWeb

// Register the application module, then say what this host answers for it
// before it runs - the controls it realizes, the acts it performs and the
// pushes it reports, each in Host/ beside this file, their scripts in Page/ -
// and show it in the page; the browser calls it from then on.
stateui_app_register()
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()
StateUIWeb.run(name: "Gallery")
