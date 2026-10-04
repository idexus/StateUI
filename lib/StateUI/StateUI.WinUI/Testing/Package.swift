// swift-tools-version:6.4
import PackageDescription

// The WinUI host's tests, and the driver every conformance run on WinUI goes
// through. A package beside the host's: the tests register the host's backends
// (../../../Backends), which depend on the host, and everything here links the
// host's one dynamic library - the relay's C functions the tests call included,
// which that library exports. The driver reads the host's own views, so it is
// built where the host is built for testing: a debug build, `swift test`.
let package = Package(
    name: "StateUIWinUITesting",
    products: [
        .library(name: "StateUIWinUIDriver", targets: ["StateUIWinUIDriver"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHost", path: "../../StateUI.Host"),
        .package(name: "StateUIConformance", path: "../../StateUI.Conformance"),
        .package(name: "StateUIWinUI", path: ".."),
        .package(name: "StateUIWebViewWinUI", path: "../../../Backends/WebView.WinUI"),
    ],
    targets: [
        .target(
            name: "StateUIWinUIDriver",
            dependencies: [
                .product(name: "StateUIWinUI", package: "StateUIWinUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Sources/StateUIWinUIDriver",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIWinUITests",
            dependencies: [
                "StateUIWinUIDriver", .product(name: "StateUIWinUI", package: "StateUIWinUI"),
                .product(name: "StateUIWebViewWinUI", package: "StateUIWebViewWinUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Tests",
            // The pictures a test shows, read from where they stand rather than bundled.
            exclude: ["Resources"],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
