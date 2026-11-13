// swift-tools-version:6.4
import PackageDescription

// `stateui`, StateUI's developer tool: one implementation that creates, builds, runs, tests and packages StateUI
// applications for the terminal, automation and editors. It links no StateUI runtime and stands in no
// application's graph; its own dependencies stay here.
let package = Package(
    name: "StateUI.CLI",
    platforms: [
        .macOS("26.4"),
    ],
    products: [
        .executable(name: "stateui", targets: ["StateUICLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.8.2"),
        .package(url: "https://github.com/swiftlang/swift-subprocess", exact: "1.0.2"),
    ],
    targets: [
        // The terminal: arguments, presentation and the editor service's entry.
        .executableTarget(
            name: "StateUICLI",
            dependencies: [
                "StateUITooling",
                "StateUIToolingProtocol",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/StateUICLI"
        ),
        // The work every client shares: projects, toolchains, processes, artifacts and sessions.
        .target(
            name: "StateUITooling",
            dependencies: [
                "StateUIToolingProtocol",
                .product(name: "Subprocess", package: "swift-subprocess"),
            ],
            path: "Sources/StateUITooling"
        ),
        // The external contract: the messages a terminal's JSON and an editor's JSON-RPC carry.
        .target(name: "StateUIToolingProtocol", path: "Sources/StateUIToolingProtocol"),
        // A program the process runner's tests run, the same on every system.
        .executableTarget(name: "ProcessProbe", path: "Tests/ProcessProbe"),
        .testTarget(
            name: "StateUIToolingTests",
            dependencies: ["StateUITooling"],
            path: "Tests/StateUIToolingTests"
        ),
        .testTarget(
            name: "StateUIToolingProtocolTests",
            dependencies: ["StateUIToolingProtocol"],
            path: "Tests/StateUIToolingProtocolTests"
        ),
        // Runs the built `stateui` as a user does.
        .testTarget(
            name: "StateUICLITests",
            dependencies: ["StateUITooling", "StateUIToolingProtocol"],
            path: "Tests/StateUICLITests"
        ),
    ]
)
