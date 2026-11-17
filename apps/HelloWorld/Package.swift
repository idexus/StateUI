// swift-tools-version:6.4
import PackageDescription

// The application's own Swift module, HelloWorldUI, and its tests. SourceKit
// understands only code a SwiftPM package holds, so the editor completes the
// application through this manifest as well.
//
// Each head is a package of its own, Platforms/<Host>, which builds this module
// for its host by enabling the host's trait here - one of `hosts` - and that
// trait defines the host's condition: the application's Swift for that host
// alone stands under it, `#if APPKIT`. A build with no trait is plain Swift.
let hosts = ["AppKit", "UIKit", "Android", "WinUI", "GTK", "Web"]

// NonisolatedNonsendingByDefault is the one setting an application must not
// leave out; see the note in ../../Package.swift. MemberImportVisibility holds
// each file to the modules it imports itself: a member of StateUI written
// where no `import StateUI` stands fails on every host.
let settings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
] + hosts.map { .define($0.uppercased(), .when(traits: [$0])) }

// The platforms that link a library dynamically: every one but WebAssembly.
let dynamicLinking: [Platform] = [.macOS, .macCatalyst, .iOS, .linux, .windows, .android]

let package = Package(
    name: "HelloWorldUI",
    // StateUI's floor, which an application cannot go below.
    platforms: [
        .iOS("26.4"),
        .macCatalyst("26.4"),
        .macOS("26.4"),
    ],
    products: [
        // Linked into the head; StateUI is the one dynamic library a process holds.
        .library(name: "HelloWorldUI", targets: ["HelloWorldUI"]),
    ],
    traits: Set(hosts.map { Trait(name: $0) }),
    // The StateUI checkout: the library at its root, and what the tests show its pages through.
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
        .package(name: "StateUITesting", path: "../../lib/StateUI/StateUI.Testing"),
    ],
    targets: [
        // StateUI is dynamic, so a head and its host share one runtime; WebAssembly links one module, so a build for
        // it takes StateUI static.
        .target(
            name: "HelloWorldUI",
            dependencies: [
                .product(name: "StateUI", package: "StateUIRoot", condition: .when(platforms: dynamicLinking)),
                .product(name: "StateUIStatic", package: "StateUIRoot", condition: .when(platforms: [.wasi])),
            ],
            path: "Sources", swiftSettings: settings),
        // The application's tests - `swift test`, or StateUI: Run Tests - which show its pages in a test's window.
        .testTarget(
            name: "HelloWorldTests",
            dependencies: ["HelloWorldUI", .product(name: "StateUITesting", package: "StateUITesting")],
            path: "Tests", swiftSettings: settings),
    ]
)
