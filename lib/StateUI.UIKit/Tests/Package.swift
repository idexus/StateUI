// swift-tools-version:6.4
import PackageDescription

// The UIKit host's tests. A view stands in a window scene only in an application's process, so the tests are an
// application of their own, run on the main thread once its first scene connects.
// .scripts/UIKit/test-uikit.sh builds, installs and runs it on a simulator.
let package = Package(
    name: "StateUIUIKitTests",
    platforms: [.iOS(.v26)],
    products: [
        .executable(name: "StateUIUIKitTests", targets: ["StateUIUIKitTests"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIUIKit", path: ".."),
        .package(name: "StateUIHost", path: "../../StateUI.Host"),
        .package(name: "StateUIConformance", path: "../../StateUI.Conformance"),
    ],
    targets: [
        .executableTarget(
            name: "StateUIUIKitTests",
            dependencies: [
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIUIKit", package: "StateUIUIKit"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
            linkerSettings: [.linkedFramework("XCTest"), .linkedFramework("UIKit")]
        ),
    ]
)
