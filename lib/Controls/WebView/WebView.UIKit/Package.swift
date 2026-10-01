// swift-tools-version:6.4
import PackageDescription

// The web view's UIKit backend: WebKit's web view, realized through the UIKit
// host's registration of an application's own views. A package of its own, as
// the UIKit host is beside StateUI: an application showing a web view on UIKit
// depends on it from its UIKit head and calls StateUIWebViewUIKit.register()
// before it runs.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault"), .define("UIKIT")]

let package = Package(
    name: "StateUIWebViewUIKit",
    platforms: [.iOS(.v26)],
    products: [
        // Dynamic, as the UIKit host is: a head links it once beside the host.
        .library(name: "StateUIWebViewUIKit", type: .dynamic, targets: ["StateUIWebViewUIKit"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIWebView", path: ".."),
        .package(name: "StateUIWebViewHost", path: "../WebView.Host"),
        .package(name: "StateUIUIKit", path: "../../../StateUI.UIKit"),
    ],
    targets: [
        .target(
            name: "StateUIWebViewUIKit",
            dependencies: [
                .product(name: "StateUIWebView", package: "StateUIWebView"),
                .product(name: "StateUIWebViewHost", package: "StateUIWebViewHost"),
                .product(name: "StateUIUIKit", package: "StateUIUIKit"),
                .product(name: "StateUI", package: "StateUIRoot"),
            ],
            path: "Sources/StateUIWebViewUIKit", swiftSettings: settings,
            linkerSettings: [.linkedFramework("WebKit")]),
    ]
)
