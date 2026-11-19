// swift-tools-version:6.4
import PackageDescription

// The Web host's own suite and its conformance run: XCTest compiled to WebAssembly, which `stateui repo test --suite
// host:web` runs in Node over a page with just enough of a DOM (JavaScript/page.mjs) - and, for the conformance suite, in a
// browser (JavaScript/run-in-browser.mjs) - the host's own relay beneath it, and the driver's functions reading what
// the page holds, which CWebTesting declares. It builds with the Swift SDK for WebAssembly, every library linked into
// the one module.
let package = Package(
    name: "StateUIWebTesting",
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHost", path: "../../StateUI.Host"),
        .package(name: "StateUIConformance", path: "../../StateUI.Conformance"),
        .package(name: "StateUITesting", path: "../../StateUI.Testing"),
        .package(name: "StateUIWeb", path: ".."),
    ],
    targets: [
        // The driver's functions, and nothing else.
        .systemLibrary(name: "CWebTesting", path: "Sources/CWebTesting"),
        .testTarget(
            name: "StateUIWebTests",
            dependencies: [
                "CWebTesting", .product(name: "StateUIWeb", package: "StateUIWeb"),
                .product(name: "StateUIHostStatic", package: "StateUIHost"), .product(name: "StateUIStatic", package: "StateUIRoot"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
                .product(name: "StateUITesting", package: "StateUITesting"),
            ],
            path: "Tests",
            exclude: ["Resources"],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")],
            // The stack a Web head links with: 8 MB, first in memory (docs/design/platforms/web/runtime.md#the-stack).
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "--export-table", "-Xlinker", "--stack-first",
                "-Xlinker", "-z", "-Xlinker", "stack-size=8388608", "-Xlinker", "--global-base=8388608",
            ])]
        ),
    ]
)
