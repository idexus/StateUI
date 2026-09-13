// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import GalleryUI
import StateUIAppKit

stateui_app_register()

let bundledResources = Bundle.main.resourceURL?.appendingPathComponent(
    "Images", isDirectory: true)
let sourceResources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Resources/Images", isDirectory: true)
let resources = bundledResources.flatMap {
    FileManager.default.fileExists(atPath: $0.path) ? $0 : nil
} ?? sourceResources
let bundledIcon = Bundle.main.url(forResource: "StateUI", withExtension: "icns")
let icon = bundledIcon ?? resources.appendingPathComponent("stateui_tile.svg")

StateUIAppKit.run(resourceDirectory: resources, applicationIcon: icon)
