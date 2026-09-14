import Foundation
import StateUIStarterUI
import StateUIAppKit

// Register the application module before the native host requests its root.
stateui_app_register()

let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources/Images", isDirectory: true)

StateUIAppKit.run(resourceDirectory: resources)
