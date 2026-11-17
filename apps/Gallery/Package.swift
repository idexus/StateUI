// swift-tools-version:6.4
import PackageDescription

// The application's own Swift module, GalleryUI, and its acceptance tests.
// SourceKit understands only code a SwiftPM package holds, so the editor
// completes the application through this manifest as well.
//
// Each head is a package of its own, Platforms/<Host>, which builds this module
// for its host by enabling the host's trait here - one of `hosts` - and that
// trait defines the host's condition: the application's Swift for that host
// alone stands under it, `#if APPKIT`. A build with no trait is plain Swift,
// so `swift test` compiles no line of any host's half.
let hosts = ["AppKit", "UIKit", "Android", "WinUI", "GTK", "Web"]

// NonisolatedNonsendingByDefault is the one setting an application must not
// leave out; see the note in ../../Package.swift. MemberImportVisibility holds
// each file to the modules it imports itself: a member of StateUI, or one
// Foundation adds, written where no import of it stands fails on every host.
let settings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
] + hosts.map { .define($0.uppercased(), .when(traits: [$0])) }

// The platforms that link a library dynamically: every one but WebAssembly.
let dynamicLinking: [Platform] = [.macOS, .macCatalyst, .iOS, .linux, .windows, .android]

let package = Package(
    name: "GalleryUI",
    // StateUI's floor, which an application cannot go below.
    platforms: [
        .iOS("26.4"),
        .macCatalyst("26.4"),
        .macOS("26.4"),
    ],
    products: [
        // Linked into the head; StateUI is the one dynamic library a process holds.
        .library(name: "GalleryUI", targets: ["GalleryUI"]),
    ],
    traits: Set(hosts.map { Trait(name: $0) }),
    // The StateUI checkout: the library at its root, the host layer the tests walk the gallery over, and the testing
    // library they use its samples through.
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
        .package(name: "StateUIHost", path: "../../lib/StateUI/StateUI.Host"),
        .package(name: "StateUITesting", path: "../../lib/StateUI/StateUI.Testing"),
    ],
    targets: [
        // StateUI is dynamic, so a head and its host share one runtime; WebAssembly links one module, so a build for
        // it takes StateUI static.
        .target(
            name: "GalleryUI",
            dependencies: [
                .product(name: "StateUI", package: "StateUIRoot", condition: .when(platforms: dynamicLinking)),
                .product(name: "StateUIStatic", package: "StateUIRoot", condition: .when(platforms: [.wasi])),
            ],
            path: "Sources", swiftSettings: settings),
        // The tests walk the gallery over the host layer too, every sample visited and left (LeakWalkTests), and use
        // its samples as their user does through a test's window (StateUITesting).
        .testTarget(
            name: "GalleryTests",
            dependencies: [
                "GalleryUI", .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUITesting", package: "StateUITesting"),
            ],
            path: "Tests/GalleryTests",
            swiftSettings: settings
        ),
    ]
)
