// swift-tools-version:6.4
import PackageDescription

// The web view's Android backend: Android's web view, realized through the
// Android host's registration of an application's own controls. A package of
// its own, as the Android host is beside StateUI: an application showing a web
// view on Android depends on it from its Android head, calls
// StateUIWebViewAndroid.register() as its library loads, and compiles this
// package's Java folder into its APK.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault"), .define("ANDROID")]

let package = Package(
    name: "StateUIWebViewAndroid",
    products: [
        // Dynamic, as the Android host is: the head's library links it once beside the host.
        .library(name: "StateUIWebViewAndroid", type: .dynamic, targets: ["StateUIWebViewAndroid"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIWebView", path: ".."),
        .package(name: "StateUIWebViewHost", path: "../WebView.Host"),
        .package(name: "StateUIAndroid", path: "../../../StateUI.Android"),
    ],
    targets: [
        .target(
            name: "StateUIWebViewAndroid",
            dependencies: [
                .product(name: "StateUIWebView", package: "StateUIWebView"),
                .product(name: "StateUIWebViewHost", package: "StateUIWebViewHost"),
                .product(name: "StateUIAndroid", package: "StateUIAndroid"),
                .product(name: "StateUI", package: "StateUIRoot"),
            ],
            path: "Sources/StateUIWebViewAndroid", swiftSettings: settings),
    ]
)
