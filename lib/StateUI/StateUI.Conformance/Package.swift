// swift-tools-version:6.4
import PackageDescription

// The conformance suite: what executing StateUI's contract does, written once
// and run on every host against its real toolkit. Each host's tests link it
// and supply a driver. A package of its own beside the core's tests,
// as the hosts are packages of their own, so the one dynamic StateUI runtime is
// linked rather than copied.

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
    name: "StateUIConformance",
    platforms: [.iOS("26.4"), .macOS("26.4")],
    products: [
        .library(name: "StateUIConformance", targets: ["StateUIConformance"]),
        .executable(name: "stateui-conformance-metadata", targets: ["StateUIConformanceMetadata"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../StateUI.Host"),
    ],
    targets: [
        .target(
            name: "StateUIConformance",
            dependencies: core,
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        // What the stateui tool reads a family's revision and recorded verdicts through: the library's own reader.
        .executableTarget(
            name: "StateUIConformanceMetadata",
            dependencies: ["StateUIConformance", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Metadata/Sources"
        ),
        .testTarget(
            name: "StateUIConformanceTests",
            dependencies: ["StateUIConformance", .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost")],
            path: "Tests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
