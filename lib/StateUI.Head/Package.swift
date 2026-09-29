// swift-tools-version:6.4
import PackageDescription

// What every application's head is built with: the host its build is for.
//
// A build names its host by one variable - STATEUI_APPKIT, STATEUI_UIKIT,
// STATEUI_ANDROID, STATEUI_WINUI or STATEUI_GTK - which its script or the
// editor sets. This manifest reads it once for every application: it depends
// on that host's package, and StateUIHead re-exports it. An application's
// manifest declares its head in Platforms/<Host> and names StateUIHead there,
// with no host package of its own.
let host = ["AppKit", "UIKit", "Android", "WinUI", "GTK"]
    .first { Context.environment["STATEUI_\($0.uppercased())"] == "1" }

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
    dependencies: host.map { [.package(name: "StateUI\($0)", path: "../StateUI.\($0)")] } ?? [],
    targets: [
        .target(
            name: "StateUIHead",
            dependencies: host.map { [.product(name: "StateUI\($0)", package: "StateUI\($0)")] } ?? [],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
                + (host.map { [.define($0.uppercased())] } ?? []),
            // A WinUI head is a windowed application: started by itself it opens no console, and started from one it
            // writes there.
            linkerSettings: host == "WinUI"
                ? [.unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"])]
                : []
        ),
    ]
)
