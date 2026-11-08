// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// listing: winui.md.head
import GalleryUI
import StateUI
import StateUIWebViewWinUI
import StateUIWinUI

// Name the application to the host, then say what this host answers for it before it runs: the controls it realizes,
// the acts it performs, and the pushes it reports - each in Host/ beside this file, the elements made by the gallery's
// relay in Relay/. Then hand WinUI this thread until the last window closes.
GalleryApp.register()
// listing: InteropActsSample.WinUI.swift
// Before WinUIHost.run(): every control - RatingBarControl.register() among them - and every act.
GalleryControls.register()
GalleryActs.register()
// listing: end
// listing: InteropEventsSample.WinUI.swift
// Before WinUIHost.run(): the pushes this host raises, their source wired.
GalleryEventSources.start()
// listing: end
// The backends the Gallery shows a library element through: the web view, over WebView2.
WebViewWinUI.register()
WinUIHost.run(linkSchemes: ["stateui-gallery"])
// listing: end
