// swift-tools-version:6.4
import PackageDescription

// The web view's GTK backend: WebKitGTK 6.0's web view, realized through the
// GTK host's registration of an application's own controls. A package of its
// own, as the GTK host is beside StateUI: an application showing a web view on
// GTK depends on it from its GTK head and calls StateUIWebViewGTK.register()
// before it runs; nothing else links WebKit. Its tests run the web view's
// families through the GTK host's driver.

// NonisolatedNonsendingByDefault, as every StateUI package; see ../../../../Package.swift.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault"), .define("GTK")]

let stateUI: Target.Dependency = .product(name: "StateUI", package: "StateUIRoot")
let webView: Target.Dependency = .product(name: "StateUIWebView", package: "StateUIWebView")
let gtk: Target.Dependency = .product(name: "StateUIGTK", package: "StateUIGTK")

let package = Package(
    name: "StateUIWebViewGTK",
    products: [
        // Dynamic, as the GTK host is: a head links it once beside the host.
        .library(name: "StateUIWebViewGTK", type: .dynamic, targets: ["StateUIWebViewGTK"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIWebView", path: ".."),
        .package(name: "StateUIGTK", path: "../../../StateUI/StateUI.GTK"),
        .package(name: "StateUIGTKTesting", path: "../../../StateUI/StateUI.GTK/Testing"),
        .package(name: "StateUIWebViewHost", path: "../WebView.Host"),
        .package(name: "StateUIWebViewConformance", path: "../WebView.Conformance"),
        .package(name: "StateUIConformance", path: "../../../StateUI/StateUI.Conformance"),
    ],
    targets: [
        // WebKitGTK 6.0's calls, declared by themselves; pkg-config links the engine.
        .systemLibrary(name: "CWebKitGTK", path: "Sources/CWebKitGTK", pkgConfig: "webkitgtk-6.0"),
        .target(
            name: "StateUIWebViewGTK",
            dependencies: [
                "CWebKitGTK", webView, .product(name: "StateUIWebViewHost", package: "StateUIWebViewHost"), gtk, stateUI,
            ],
            path: "Sources/StateUIWebViewGTK", swiftSettings: settings),
        .testTarget(
            name: "StateUIWebViewGTKTests",
            dependencies: [
                "StateUIWebViewGTK", "CWebKitGTK", webView, gtk, stateUI,
                .product(name: "StateUIWebViewConformance", package: "StateUIWebViewConformance"),
                .product(name: "StateUIGTKDriver", package: "StateUIGTKTesting"),
                .product(name: "StateUIConformance", package: "StateUIConformance"),
            ],
            path: "Tests", swiftSettings: settings),
    ]
)
