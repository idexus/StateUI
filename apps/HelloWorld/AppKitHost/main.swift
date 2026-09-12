// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import HelloWorldUI
import StateUIAppKit

// This is the same registration function the MAUI host calls after loading
// HelloWorldUI. Only the host after this line differs.
stateui_app_register()

let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("apps/HelloWorld/Resources/Images", isDirectory: true)

StateUIAppKit.run(resourceDirectory: resources)
