// swift-tools-version:6.4
import PackageDescription

// The web view's conformance family - its cases, its specimen among the
// families of the tiers it wears, and the revision its verdicts stand at
// (revisions.txt) - which each backend's tests run through its host's driver,
// and the test that holds the family to the contract. A package beside the web
// view's, as StateUI.Conformance is beside StateUI.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]

let package = Package(
    name: "StateUIWebViewConformance",
    // StateUI's floor, which a component cannot go below.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "StateUIWebViewConformance", targets: ["StateUIWebViewConformance"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIConformance", path: "../../../StateUI/StateUI.Conformance"),
        .package(name: "StateUIWebView", path: ".."),
    ],
    targets: [
        .target(
            name: "StateUIWebViewConformance",
            dependencies: [
                .product(name: "StateUIWebView", package: "StateUIWebView"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Sources/StateUIWebViewConformance", swiftSettings: settings),
        .testTarget(
            name: "StateUIWebViewConformanceTests",
            dependencies: [
                "StateUIWebViewConformance", .product(name: "StateUIWebView", package: "StateUIWebView"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Tests", swiftSettings: settings),
    ]
)
