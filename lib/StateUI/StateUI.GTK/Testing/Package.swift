// swift-tools-version:6.4
import PackageDescription

// The GTK host's tests, and the driver every conformance run on GTK goes
// through. A package beside the host's: the tests register the host's backends
// (../../../Backends), which depend on the host, and everything here links the
// host's one dynamic library. The driver reads the host's own views, so it is
// built where the host is built for testing: a debug build, `swift test`.
let package = Package(
    name: "StateUIGTKTesting",
    products: [
        .library(name: "StateUIGTKDriver", targets: ["StateUIGTKDriver"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHost", path: "../../StateUI.Host"),
        .package(name: "StateUIConformance", path: "../../StateUI.Conformance"),
        .package(name: "StateUIGTK", path: ".."),
        .package(name: "StateUIWebViewGTK", path: "../../../Backends/WebView.GTK"),
    ],
    targets: [
        // GTK's checks of what an accessible holds, for the driver: GTK declares them with arguments Swift cannot pass.
        .systemLibrary(name: "CGTKTesting", path: "Sources/CGTKTesting"),
        .target(
            name: "StateUIGTKDriver",
            dependencies: [
                "CGTKTesting", .product(name: "StateUIGTK", package: "StateUIGTK"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Sources/StateUIGTKDriver",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIGTKTests",
            dependencies: [
                "StateUIGTKDriver", .product(name: "StateUIGTK", package: "StateUIGTK"),
                .product(name: "StateUIWebViewGTK", package: "StateUIWebViewGTK"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Tests",
            exclude: ["Resources"],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
