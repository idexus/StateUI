// swift-tools-version:6.4
import PackageDescription

// The GTK 4 host: Swift in the application's process, reading the typed patch
// and calling GTK 4 and libadwaita through their C API - no relay beneath it.
// A sibling package, as the AppKit, Android Views and WinUI hosts are, so the
// one dynamic StateUI runtime is linked into the application rather than
// copied into a second library in the same process. It builds on Linux, where
// pkg-config finds libadwaita and the GTK it needs. Its tests, and the driver
// a conformance run on GTK goes through, stand in the package in Testing.
let package = Package(
    name: "StateUIGTK",
    products: [
        .library(name: "StateUIGTK", type: .dynamic, targets: ["StateUIGTK"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
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
    ]
)
