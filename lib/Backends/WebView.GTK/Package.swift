// swift-tools-version:6.4
import PackageDescription

// The web view's GTK backend: WebKitGTK 6.0's web view, realized through the
// GTK host's registration of an application's own controls. A package of its
// own because WebKitGTK is a library the platform does not ship with GTK: an
// application showing a web view on GTK depends on it from its GTK head and
// calls StateUIWebViewGTK.register() before it runs; nothing else links WebKit.
// The GTK host's tests register it and run the web view's family through it.

// NonisolatedNonsendingByDefault, as every StateUI package; see ../../../Package.swift.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault"), .define("GTK")]

let package = Package(
    name: "StateUIWebViewGTK",
    products: [
        // Dynamic, as the GTK host is: a head links it once beside the host.
        .library(name: "StateUIWebViewGTK", type: .dynamic, targets: ["StateUIWebViewGTK"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../../StateUI/StateUI.Host"),
        .package(name: "StateUIGTK", path: "../../StateUI/StateUI.GTK"),
    ],
    targets: [
        // WebKitGTK 6.0's calls, declared by themselves; pkg-config links the engine.
        .systemLibrary(name: "CWebKitGTK", path: "Sources/CWebKitGTK", pkgConfig: "webkitgtk-6.0"),
        .target(
            name: "StateUIWebViewGTK",
            dependencies: [
                "CWebKitGTK",
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIGTK", package: "StateUIGTK"),
                .product(name: "StateUI", package: "StateUIRoot"),
            ],
            path: "Sources/StateUIWebViewGTK", swiftSettings: settings),
    ]
)
