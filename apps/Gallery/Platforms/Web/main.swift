// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// listing: web.md.head
import GalleryUI
import StateUI
import StateUIWeb

// Name the application to the host, then say what this host answers for it
// before it runs - the controls it realizes, the acts it performs and the
// pushes it reports, each in Host/ beside this file, their scripts in Page/ -
// and show it in the page; the browser calls it from then on.
GalleryApp.register()
GalleryControls.register()
GalleryActs.register()
// listing: InteropEventsSample.Web.swift
GalleryEventSources.start()
WebHost.run(name: "Gallery", applicationID: "com.stateui.gallery")
// listing: end
// listing: end
