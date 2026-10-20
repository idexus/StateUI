// swift-tools-version:6.4
import PackageDescription

// What the hosts of Apple's platforms - AppKit and UIKit - share: WebKit's web view, MapKit's map, the facts of the
// system both read alike. A sibling of the hosts, a dynamic library as they are, so a process holds one copy of its
// types; the host layer stays free of Foundation.
let package = Package(
    name: "StateUIApple",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "StateUIApple", type: .dynamic, targets: ["StateUIApple"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
    ],
    targets: [
        .target(
            name: "StateUIApple",
            dependencies: [.product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
            linkerSettings: [.linkedFramework("WebKit")]
        ),
    ]
)
