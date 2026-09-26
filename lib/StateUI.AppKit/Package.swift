// swift-tools-version:6.4
import PackageDescription

// A separate package is deliberate. Keeping AppKit as a sibling host package
// makes SwiftPM link the one dynamic StateUI runtime into the executable instead
// of copying StateUI's object files into a second library in the same process.
let package = Package(
    name: "StateUIAppKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "StateUIAppKit", type: .dynamic, targets: ["StateUIAppKit"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
        .package(name: "StateUIConformance", path: "../StateUI.Conformance"),
    ],
    targets: [
        .target(
            name: "StateUIAppKit",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
        .testTarget(
            name: "StateUIAppKitTests",
            dependencies: [
                "StateUIAppKit",
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Tests",
            exclude: ["Resources"],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
    ]
)
