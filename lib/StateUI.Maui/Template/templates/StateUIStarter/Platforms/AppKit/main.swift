import Foundation
import StateUIStarterUI
import StateUIAppKit

// Register the application module before the native host requests its root.
stateui_app_register()

// The application's artwork, found beside this file's sources: SwiftPM builds
// no bundle to carry it, so it is read where the application keeps it,
// wherever the head is started from.
let resources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Resources/Images", isDirectory: true)

StateUIAppKit.run(
    resourceDirectory: resources,
    applicationIcon: resources.appendingPathComponent("stateui_tile.svg"))
