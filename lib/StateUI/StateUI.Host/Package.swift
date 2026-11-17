// swift-tools-version:6.4
import PackageDescription

// The host layer: the half of every StateUI runtime no toolkit decides, which every host - AppKit, UIKit, Android
// Views, WinUI, GTK, Web - stands on. A dynamic library, as the core is, so a process holds one copy of its types;
// StateUIHostStatic for WebAssembly, which links one module, as StateUI's own two products are taken.

// The platforms that link a library dynamically: every one but WebAssembly.
let dynamicLinking: [Platform] = [.macOS, .macCatalyst, .iOS, .linux, .windows, .android]

let stateUI: [Target.Dependency] = [
    .product(name: "StateUI", package: "StateUIRoot", condition: .when(platforms: dynamicLinking)),
    .product(name: "StateUIStatic", package: "StateUIRoot", condition: .when(platforms: [.wasi])),
]

let package = Package(
    name: "StateUIHost",
    platforms: [
        .iOS("26.4"),
        .macCatalyst("26.4"),
        .macOS("26.4"),
    ],
    products: [
        .library(name: "StateUIHost", type: .dynamic, targets: ["StateUIHost"]),
        .library(name: "StateUIHostStatic", type: .static, targets: ["StateUIHost"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
    ],
    targets: [
        // libdispatch's main queue as a run loop turns it: its handle and its drain.
        .systemLibrary(name: "CStateUIHost", path: "CStateUIHost"),
        .target(
            name: "StateUIHost",
            dependencies: ["CStateUIHost"] + stateUI,
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIHostTests",
            dependencies: ["StateUIHost", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Tests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        // The work four gestures cost the core and this layer on a clock wound by hand: the counts a gate in every
        // run, the times a trend read from a release build (docs/design/host/benchmarks.md).
        .testTarget(
            name: "StateUIHostBenchmarks",
            dependencies: ["StateUIHost", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Benchmarks",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
