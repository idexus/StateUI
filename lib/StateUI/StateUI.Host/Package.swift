// swift-tools-version:6.4
import PackageDescription

// The host layer: the half of every StateUI runtime no toolkit decides, which every host - AppKit, UIKit, Android
// Views, WinUI, GTK, Web - stands on. A dynamic library, as the core is, so a process holds one copy of its types;
// in a Web build (STATEUI_HOST=web) a static one, as WebAssembly links one module.
let linkage: Product.Library.LibraryType? = Context.environment["STATEUI_HOST"] == "web" ? nil : .dynamic

let package = Package(
    name: "StateUIHost",
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "StateUIHost", type: linkage, targets: ["StateUIHost"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
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
