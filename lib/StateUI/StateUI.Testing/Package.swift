// swift-tools-version:6.4
import PackageDescription

// What an application's tests import to show its pages and use them as its user does: a window with no toolkit,
// over the core and the host layer, where `swift test` runs. A package of its own, as the hosts are, so the one
// dynamic StateUI runtime is linked rather than copied.
let package = Package(
    name: "StateUITesting",
    platforms: [.iOS("26.4"), .macOS("26.4")],
    products: [
        .library(name: "StateUITesting", targets: ["StateUITesting"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
    ],
    targets: [
        .target(
            name: "StateUITesting",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUITestingTests",
            dependencies: ["StateUITesting", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Tests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
