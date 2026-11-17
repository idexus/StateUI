// swift-tools-version:6.4
import PackageDescription

// What an application's tests import to show its pages and use them as its user does: a window with no toolkit,
// over the core and the host layer, where `swift test` runs. A package of its own, as the hosts are, so the one
// dynamic StateUI runtime is linked rather than copied.

// The platforms that link a library dynamically: every one but WebAssembly.
let dynamicLinking: [Platform] = [.macOS, .macCatalyst, .iOS, .linux, .windows, .android]

// The core and the host layer, dynamic, and for WebAssembly, which links one module, static.
let core: [Target.Dependency] = [
    .product(name: "StateUI", package: "StateUIRoot", condition: .when(platforms: dynamicLinking)),
    .product(name: "StateUIHost", package: "StateUIHost", condition: .when(platforms: dynamicLinking)),
    .product(name: "StateUIStatic", package: "StateUIRoot", condition: .when(platforms: [.wasi])),
    .product(name: "StateUIHostStatic", package: "StateUIHost", condition: .when(platforms: [.wasi])),
]

let package = Package(
    name: "StateUITesting",
    platforms: [.iOS("26.4"), .macOS("26.4")],
    products: [
        .library(name: "StateUITesting", targets: ["StateUITesting"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
    ],
    targets: [
        .target(
            name: "StateUITesting",
            dependencies: core,
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUITestingTests",
            dependencies: ["StateUITesting", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Tests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
