// swift-tools-version:6.4
import PackageDescription

// The map's conformance families - the map's and its pins' cases, the map's
// specimen among the families of the tiers it wears, and the revision their
// verdicts stand at (revisions.txt) - which each backend's tests run through
// its host's driver, and the test that holds each family to its contract. A
// package beside the map's, as StateUI.Conformance is beside StateUI.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]

let package = Package(
    name: "StateUIMapConformance",
    // StateUI's floor, which a component cannot go below.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "StateUIMapConformance", targets: ["StateUIMapConformance"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIConformance", path: "../../../StateUI/StateUI.Conformance"),
        .package(name: "StateUIMap", path: ".."),
    ],
    targets: [
        .target(
            name: "StateUIMapConformance",
            dependencies: [
                .product(name: "StateUIMap", package: "StateUIMap"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Sources/StateUIMapConformance", swiftSettings: settings),
        .testTarget(
            name: "StateUIMapConformanceTests",
            dependencies: [
                "StateUIMapConformance", .product(name: "StateUIMap", package: "StateUIMap"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Tests", swiftSettings: settings),
    ]
)
