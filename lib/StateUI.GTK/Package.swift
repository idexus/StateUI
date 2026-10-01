// swift-tools-version:6.4
import PackageDescription

// The GTK 4 host: Swift in the application's process, reading the typed patch
// and calling GTK 4 and libadwaita through their C API - no relay beneath it.
// A sibling package, as the AppKit, Android Views and WinUI hosts are, so the
// one dynamic StateUI runtime is linked into the application rather than
// copied into a second library in the same process. It builds on Linux, where
// pkg-config finds libadwaita and the GTK it needs.
let package = Package(
    name: "StateUIGTK",
    products: [
        .library(name: "StateUIGTK", type: .dynamic, targets: ["StateUIGTK"]),
        // What runs the conformance families on GTK - this package's tests, and a component's.
        .library(name: "StateUIGTKDriver", targets: ["StateUIGTKDriver"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
        .package(name: "StateUIConformance", path: "../StateUI.Conformance"),
    ],
    targets: [
        // GTK's and libadwaita's headers and libraries, and nothing else.
        .systemLibrary(name: "CStateUIGTK", path: "Sources/CStateUIGTK", pkgConfig: "libadwaita-1"),
        .target(
            name: "StateUIGTK",
            dependencies: ["CStateUIGTK", .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Sources/StateUIGTK",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        // GTK's checks of what an accessible holds, for the driver: GTK declares them with arguments Swift cannot pass.
        .systemLibrary(name: "CGTKTesting", path: "Sources/CGTKTesting"),
        // The driver reads the host's own views, so it is built where the host is built for testing: by `swift test`.
        .target(
            name: "StateUIGTKDriver",
            dependencies: [
                "StateUIGTK", "CStateUIGTK", "CGTKTesting", .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Sources/StateUIGTKDriver",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIGTKTests",
            dependencies: [
                "StateUIGTK", "StateUIGTKDriver", "CStateUIGTK", .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Tests",
            exclude: ["Resources"],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
