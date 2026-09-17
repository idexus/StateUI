// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import GalleryUI
import StateUIAppKit

stateui_app_register()

// What this host answers for the application, said before it runs: the
// controls it realizes, the acts it performs, and the pushes it reports. Each
// lives in Host/ beside this file.
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()

let bundledResources = Bundle.main.resourceURL?.appendingPathComponent(
    "Images", isDirectory: true)
let sourceApplication = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let sourceResources = sourceApplication.appendingPathComponent("Resources/Images", isDirectory: true)
let resources = bundledResources.flatMap {
    FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
} ?? sourceResources
let bundledIcon = Bundle.main.url(forResource: "StateUI", withExtension: "icns")
let icon = bundledIcon ?? sourceApplication.appendingPathComponent("Resources/AppIcon/appicon_macos.svg")

StateUIAppKit.run(resourceDirectory: resources, applicationIcon: icon)
