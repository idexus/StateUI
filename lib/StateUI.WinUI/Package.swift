// swift-tools-version:6.4
import PackageDescription

// The WinUI 3 host: Swift in the application's process, reading the typed
// patch and calling WinUI through a C++/WinRT relay behind a C ABI. A sibling
// package, as the AppKit and Android Views hosts are, so the one dynamic
// StateUI runtime is linked into the application rather than copied into a
// second library in the same process. It builds on Windows alone:
// .scripts/WinUI/tools.ps1 generates the C++/WinRT projection the relay
// includes, into .projection/, and lays the Windows App SDK beside what is built.
let package = Package(
    name: "StateUIWinUI",
    products: [
        .library(name: "StateUIWinUI", type: .dynamic, targets: ["StateUIWinUI"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
    ],
    targets: [
        // The relay: WinUI's subclasses, its events, the doorbell's post and the
        // frame clock, behind the C functions its header declares.
        .target(
            name: "CStateUIWinUI",
            path: "Sources/CStateUIWinUI",
            cxxSettings: [.headerSearchPath("../../.projection")],
            // An SVG is handed to WinUI from memory; a zone's offset is ICU's, and the kept values stand in the
            // user's local data.
            linkerSettings: [
                .linkedLibrary("shcore"), .linkedLibrary("shlwapi"), .linkedLibrary("icu"), .linkedLibrary("shell32"),
                .linkedLibrary("ole32"),
            ]
        ),
        .target(
            name: "StateUIWinUI",
            dependencies: ["CStateUIWinUI", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Sources/StateUIWinUI",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUIWinUITests",
            dependencies: ["StateUIWinUI", "CStateUIWinUI", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Tests",
            // The pictures a test shows, read from where they stand rather than bundled.
            exclude: ["Resources"],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
