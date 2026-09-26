// swift-tools-version:6.4
import PackageDescription

// A separate package is deliberate, as AppKit's is: a sibling host package makes SwiftPM link the one dynamic
// StateUI runtime into the application instead of copying StateUI's object files into a second library.
let package = Package(
    name: "StateUIUIKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "StateUIUIKit", type: .dynamic, targets: ["StateUIUIKit"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
    ],
    targets: [
        .target(
            name: "StateUIUIKit",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
            linkerSettings: [.linkedFramework("UIKit")]
        ),
    ]
)
