// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import GalleryUI
import StateUIWebViewWinUI
import StateUIWinUI

// Register the application module, then say what this host answers for it before it runs: the controls it realizes,
// the acts it performs, and the pushes it reports - each in Host/ beside this file, the elements made by the gallery's
// relay in Relay/. Then hand WinUI this thread until the last window closes.
stateui_app_register()
// listing: InteropActsSample.WinUI.swift
// Before StateUIWinUI.run(): every control - RatingBarControl.register() among them - and every act.
GalleryControls.register()
GalleryActs.register()
// listing: end
// listing: InteropEventsSample.WinUI.swift
// Before StateUIWinUI.run(): the pushes this host raises, their source wired.
GalleryEventSources.start()
// listing: end
// The backends the Gallery shows a library element through: the web view, over WebView2.
StateUIWebViewWinUI.register()
StateUIWinUI.run()
