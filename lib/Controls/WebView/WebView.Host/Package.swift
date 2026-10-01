// swift-tools-version:6.4
import PackageDescription

// The web view's host layer: what every host's backend of the web view decides
// alike - a script's answer, the ways back and forward, why a navigation began,
// where a document with no address is shown - once, with its own tests. A
// package beside the web view's, as StateUI.Host is beside StateUI, so an
// application importing the web view sees none of it.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]

let package = Package(
    name: "StateUIWebViewHost",
    // StateUI's floor, which a component cannot go below.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "StateUIWebViewHost", targets: ["StateUIWebViewHost"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIWebView", path: ".."),
    ],
    targets: [
        .target(
            name: "StateUIWebViewHost",
            dependencies: [
                .product(name: "StateUIWebView", package: "StateUIWebView"),
                .product(name: "StateUI", package: "StateUIRoot"),
            ],
            path: "Sources/StateUIWebViewHost", swiftSettings: settings),
        .testTarget(
            name: "StateUIWebViewHostTests",
            dependencies: [
                "StateUIWebViewHost", .product(name: "StateUIWebView", package: "StateUIWebView"),
                .product(name: "StateUI", package: "StateUIRoot"),
            ],
            path: "Tests", swiftSettings: settings),
    ]
)
