// swift-tools-version:6.4
import PackageDescription

// The conformance suite: what executing StateUI's contract does, written once
// and run on every host against its real toolkit. Each host's test target
// links it and supplies a driver. A sibling package, as the hosts are, so the
// one dynamic StateUI runtime is linked rather than copied.
let package = Package(
    name: "StateUIHostConformance",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "StateUIHostConformance", targets: ["StateUIHostConformance"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
    ],
    targets: [
        .target(
            name: "StateUIHostConformance",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot")],
            path: "Sources/StateUIHostConformance",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIHostConformanceTests",
            dependencies: ["StateUIHostConformance", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Tests/StateUIHostConformanceTests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
