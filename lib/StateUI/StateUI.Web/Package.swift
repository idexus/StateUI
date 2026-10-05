// swift-tools-version:6.4
import PackageDescription

// The Web host: Swift compiled to WebAssembly in the page, reading the typed patch and calling the DOM through the
// JavaScript relay in JavaScript/, whose functions CStateUIWeb declares as the module's imports. A sibling package,
// as every host is. WebAssembly links no library dynamically: the application, StateUI and this host are one
// module. It builds with the Swift SDK for WebAssembly, under STATEUI_HOST=web.
let package = Package(
    name: "StateUIWeb",
    products: [
        .library(name: "StateUIWeb", targets: ["StateUIWeb"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
    ],
    targets: [
        // The relay's functions, and nothing else.
        .systemLibrary(name: "CStateUIWeb", path: "Sources/CStateUIWeb"),
        .target(
            name: "StateUIWeb",
            dependencies: ["CStateUIWeb", .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Sources/StateUIWeb",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
