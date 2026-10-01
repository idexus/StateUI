// swift-tools-version:6.4
import PackageDescription

// WebView: a component an application imports beside StateUI, so an
// application that shows no web page links neither it nor a platform's web
// engine. It is laid out as an application is: its view and contract in
// Sources/WebView, the rules every host's web view shares in Sources/Host, its
// conformance family in Sources/Conformance, and each host's realization in
// Hosts/<Host>, built for the host STATEUI_HOST names - which the application's
// head registers before it runs.
let host = ["AppKit", "UIKit", "Android", "WinUI", "GTK"]
    .first { $0.lowercased() == Context.environment["STATEUI_HOST"] }

// NonisolatedNonsendingByDefault, as every StateUI package; see ../../../Package.swift.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    + (host.map { [.define($0.uppercased())] } ?? [])

let stateUI: Target.Dependency = .product(name: "StateUI", package: "StateUIRoot")
let hostLayer: Target.Dependency = .product(name: "StateUIHost", package: "StateUIHost")
let conformance: Target.Dependency = .product(name: "StateUIConformance", package: "StateUIConformance")

var products: [Product] = [
    // Dynamic, so an application's module and its head share one copy of the view's types.
    .library(name: "StateUIWebView", type: .dynamic, targets: ["StateUIWebView"]),
]

var dependencies: [Package.Dependency] = [
    .package(name: "StateUIRoot", path: "../../.."),
    .package(name: "StateUIHost", path: "../../StateUI.Host"),
    .package(name: "StateUIConformance", path: "../../StateUI.Conformance"),
]

var targets: [Target] = [
    .target(name: "StateUIWebView", dependencies: [stateUI], path: "Sources/WebView", swiftSettings: settings),
    .target(
        name: "StateUIWebViewHost", dependencies: ["StateUIWebView", stateUI, hostLayer], path: "Sources/Host",
        swiftSettings: settings),
    .target(
        name: "StateUIWebViewConformance", dependencies: ["StateUIWebView", stateUI, hostLayer, conformance],
        path: "Sources/Conformance", swiftSettings: settings),
    .testTarget(
        name: "StateUIWebViewTests",
        dependencies: ["StateUIWebView", "StateUIWebViewHost", "StateUIWebViewConformance", stateUI, hostLayer, conformance],
        path: "Tests/WebView", swiftSettings: settings),
]

let package = Package(
    name: "StateUIWebView",
    // StateUI's floor, which a component cannot go below.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: products,
    dependencies: dependencies,
    targets: targets
)
