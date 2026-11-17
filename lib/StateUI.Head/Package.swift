// swift-tools-version:6.4
import PackageDescription

// What every application's head is built with: the host its build is for.
//
// A build names its host by one trait - AppKit, UIKit, Android, WinUI, GTK or
// Web - which a head's own package, an application's Platforms/<Host>, enables
// here and on the application. With it this package depends on that host's
// package, which StateUIHead brings into the head's graph, and defines its
// condition (`APPKIT`); with none it brings nothing. A head names no host
// package of its own; it imports StateUI and the host by name.
let hosts = ["AppKit", "UIKit", "Android", "WinUI", "GTK", "Web"]

let package = Package(
    name: "StateUIHead",
    // StateUI's floor; see the note in ../../Package.swift.
    platforms: [
        .iOS("26.4"),
        .macCatalyst("26.4"),
        .macOS("26.4"),
    ],
    products: [
        .library(name: "StateUIHead", targets: ["StateUIHead"]),
    ],
    traits: Set(hosts.map { Trait(name: $0) }),
    dependencies: hosts.map { .package(name: "StateUI\($0)", path: "../StateUI/StateUI.\($0)") },
    targets: [
        .target(
            name: "StateUIHead",
            dependencies: hosts.map { .product(name: "StateUI\($0)", package: "StateUI\($0)", condition: .when(traits: [$0])) },
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
                + hosts.map { .define($0.uppercased(), .when(traits: [$0])) },
            // A WinUI head is a windowed application: started by itself it opens no console, and started from one it
            // writes there. A Web head's module exports its function table, through which the page calls the host
            // back, and its stack is the main thread's on macOS and Linux, 8 MB, below its data, so running out of
            // it stops the program rather than overwriting what lies beyond (docs/design/platforms/web/runtime.md).
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"], .when(traits: ["WinUI"])),
                .unsafeFlags(["-Xlinker", "--export-table", "-Xlinker", "--stack-first",
                    "-Xlinker", "-z", "-Xlinker", "stack-size=8388608", "-Xlinker", "--global-base=8388608"], .when(traits: ["Web"])),
                // A release page carries no debugging information: 14.5 MB of HelloWorld rather than 23.7.
                .unsafeFlags(["-Xlinker", "--strip-debug"], .when(configuration: .release, traits: ["Web"])),
            ]
        ),
    ]
)
