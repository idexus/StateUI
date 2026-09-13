// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import HelloWorldUI
import StateUIAppKit

// Register the application module before the native host requests its root.
stateui_app_register()

let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("apps/HelloWorld/Resources/Images", isDirectory: true)

StateUIAppKit.run(resourceDirectory: resources)
