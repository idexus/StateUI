// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import HelloWorldUI
import StateUIAppKit

// Register the application module before the native host requests its root.
stateui_app_register()

// The application's artwork: beside the head, where a deployed copy carries
// it (.scripts/AppKit/deploy.sh), else where the application keeps it, found
// from this file's own place - SwiftPM builds no bundle to carry it.
let beside = Bundle.main.executableURL!.deletingLastPathComponent()
let application = FileManager.default.fileExists(atPath: beside.appendingPathComponent("Resources").path)
    ? beside
    : URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

StateUIAppKit.run(
    resourceDirectory: application.appendingPathComponent("Resources/Images", isDirectory: true),
    applicationIcon: application.appendingPathComponent("Resources/AppIcon/appicon_macos.svg"))
