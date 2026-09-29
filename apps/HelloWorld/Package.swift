// swift-tools-version:6.4
import PackageDescription

// The application's own Swift module, HelloWorldUI, and its head for the host a
// build is for. SourceKit understands only code a SwiftPM package holds, so the
// editor completes the application through this manifest as well.

// The host a build is for: the STATEUI_ variable its script or the editor sets,
// or none for plain Swift. The application's Swift for that host alone stands
// under its condition - `#if APPKIT` - and ../../lib/StateUI.Head brings the
// host itself to the head.
let host = ["AppKit", "UIKit", "Android", "WinUI", "GTK"]
    .first { Context.environment["STATEUI_\($0.uppercased())"] == "1" }

// NonisolatedNonsendingByDefault is the one setting an application must not
// leave out; see the note in ../../Package.swift.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    + (host.map { [.define($0.uppercased())] } ?? [])

var products: [Product] = [
    // Dynamic, so a head and its host share one StateUI runtime.
    .library(name: "HelloWorldUI", type: .dynamic, targets: ["HelloWorldUI"]),
]

var targets: [Target] = [
    .target(name: "HelloWorldUI", dependencies: ["StateUI"], path: "Sources", swiftSettings: settings),
    // The application's tests - `swift test`, or StateUI: Run Tests.
    .testTarget(name: "HelloWorldTests", dependencies: ["HelloWorldUI"], path: "Tests", swiftSettings: settings),
]

// The head in Platforms/<Host>: an executable its host runs, and on Android a
// library the platform loads. StateUIHead brings the host.
let head: [Target.Dependency] = ["HelloWorldUI", .product(name: "StateUIHead", package: "StateUIHead")]
switch host {
case "Android"?:
    products.append(.library(name: "HelloWorldAndroid", type: .dynamic, targets: ["HelloWorldAndroid"]))
    targets.append(.target(
        name: "HelloWorldAndroid", dependencies: head, path: "Platforms/Android/Swift", swiftSettings: settings))
case let host?:
    targets.append(.executableTarget(
        name: "HelloWorld\(host)", dependencies: head, path: "Platforms/\(host)", swiftSettings: settings))
case nil:
    break
}

let package = Package(
    name: "HelloWorldUI",
    // StateUI's floor, which an application cannot go below.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: products,
    // The StateUI checkout: the library at its root, and a head's host.
    dependencies: [.package(path: "../..")]
        + (host == nil ? [] : [.package(name: "StateUIHead", path: "../../lib/StateUI.Head")]),
    targets: targets
)
