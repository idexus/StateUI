// swift-tools-version:6.4
import PackageDescription

// WebView: a component an application imports beside StateUI, so an
// application that shows no web page links neither it nor a platform's web
// engine. It is laid out as StateUI is: this package knows no host - the view
// and its contract, in Core - and beside it, each a package of its own, WebView.Host
// holds the rules every host's backend shares, WebView.Conformance the family
// and its revisions, and WebView.<Host> each host's backend, which the
// application's head for that host depends on and registers before it runs.
// A package's folder's name is its identity, unique among every package.

// NonisolatedNonsendingByDefault, as every StateUI package; see ../../../Package.swift.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]

let stateUI: Target.Dependency = .product(name: "StateUI", package: "StateUIRoot")

let products: [Product] = [
    // Dynamic, so an application's module, its head and its backend share one copy of the view's types.
    .library(name: "StateUIWebView", type: .dynamic, targets: ["StateUIWebView"]),
]

let dependencies: [Package.Dependency] = [
    .package(name: "StateUIRoot", path: "../../.."),
]

let targets: [Target] = [
    .target(name: "StateUIWebView", dependencies: [stateUI], path: "Core/Sources", swiftSettings: settings),
    .testTarget(name: "StateUIWebViewTests", dependencies: ["StateUIWebView", stateUI], path: "Core/Tests", swiftSettings: settings),
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
