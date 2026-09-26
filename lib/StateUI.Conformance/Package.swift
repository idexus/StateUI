// swift-tools-version:6.4
import PackageDescription

// The conformance suite: what executing StateUI's contract does, written once
// and run on every host against its real toolkit. Each host's test target
// links it and supplies a driver. A package of its own beside the core's tests,
// as the hosts are packages of their own, so the one dynamic StateUI runtime is
// linked rather than copied.
let package = Package(
    name: "StateUIConformance",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "StateUIConformance", targets: ["StateUIConformance"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
    ],
    targets: [
        .target(
            name: "StateUIConformance",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIConformanceTests",
            dependencies: ["StateUIConformance", .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Tests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
