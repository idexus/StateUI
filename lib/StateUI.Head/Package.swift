// swift-tools-version:6.4
import PackageDescription

// What every application's head is built with: the host its build is for.
//
// A build names its host by one variable, STATEUI_HOST - appkit, uikit,
// android, winui, gtk or web - which its script or the editor sets. This manifest
// reads it once for every application: it depends on that host's package, and
// StateUIHead re-exports it. An application's manifest declares its head in
// Platforms/<Host> and names StateUIHead there, with no host package of its own.
let host = ["AppKit", "UIKit", "Android", "WinUI", "GTK", "Web"]
    .first { $0.lowercased() == Context.environment["STATEUI_HOST"] }

let package = Package(
    name: "StateUIHead",
    // StateUI's floor; see the note in ../../Package.swift.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: [
        .library(name: "StateUIHead", targets: ["StateUIHead"]),
    ],
    dependencies: host.map { [.package(name: "StateUI\($0)", path: "../StateUI/StateUI.\($0)")] } ?? [],
    targets: [
        .target(
            name: "StateUIHead",
            dependencies: host.map { [.product(name: "StateUI\($0)", package: "StateUI\($0)")] } ?? [],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
                + (host.map { [.define($0.uppercased())] } ?? []),
            // A WinUI head is a windowed application: started by itself it opens no console, and started from one it
            // writes there. A Web head's module exports its function table, through which the page calls the host
            // back, and its stack is the main thread's on macOS and Linux, 8 MB, below its data, so running out of
            // it stops the program rather than overwriting what lies beyond (docs/design/platforms/web/runtime.md).
            linkerSettings: host == "WinUI"
                ? [.unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"])]
                : host == "Web"
                ? [.unsafeFlags(["-Xlinker", "--export-table", "-Xlinker", "--stack-first",
                    "-Xlinker", "-z", "-Xlinker", "stack-size=8388608", "-Xlinker", "--global-base=8388608"]),
                   // A release page carries no debugging information: 14.5 MB of HelloWorld rather than 23.7.
                   .unsafeFlags(["-Xlinker", "--strip-debug"], .when(configuration: .release))]
                : []
        ),
    ]
)
