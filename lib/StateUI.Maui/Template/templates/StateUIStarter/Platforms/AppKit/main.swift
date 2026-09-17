import Foundation
import StateUIStarterUI
import StateUIAppKit

// Register the application module before the native host requests its root.
stateui_app_register()

// The application's artwork, found from this file's own place: SwiftPM builds
// no bundle to carry it, so it is read where the application keeps it,
// wherever the head is started from.
let application = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let resources = application.appendingPathComponent("Resources/Images", isDirectory: true)

StateUIAppKit.run(
    resourceDirectory: resources,
    applicationIcon: application.appendingPathComponent("Resources/AppIcon/appicon_macos.svg"))
