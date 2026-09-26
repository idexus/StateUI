// swift-tools-version:6.4
import PackageDescription

// The host layer: the half of every StateUI runtime no toolkit decides, which every host - AppKit, Android Views,
// WinUI, GTK - stands on. A dynamic library, as the core is, so a process holds one copy of its types.
let package = Package(
    name: "StateUIHost",
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "StateUIHost", type: .dynamic, targets: ["StateUIHost"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
    ],
    targets: [
        .target(
            name: "StateUIHost",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot")],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIHostTests",
            dependencies: ["StateUIHost", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Tests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
