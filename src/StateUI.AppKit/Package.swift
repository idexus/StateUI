// swift-tools-version:6.0
import PackageDescription

// A separate package is deliberate. StateUI and every application module are
// dynamic libraries for the MAUI hosts. Keeping AppKit as a sibling package
// makes SwiftPM link that one StateUI dylib into a native executable instead of
// copying StateUI's object files into a second dylib in the same process.
let package = Package(
    name: "StateUIAppKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "StateUIAppKit", type: .dynamic, targets: ["StateUIAppKit"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
    ],
    targets: [
        .target(
            name: "StateUIAppKit",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot")],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
            linkerSettings: [.linkedFramework("AppKit")]
        ),
    ]
)
