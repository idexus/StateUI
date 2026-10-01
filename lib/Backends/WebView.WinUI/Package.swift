// swift-tools-version:6.4
import PackageDescription

// The web view's WinUI backend: WinUI's WebView2, made by this package's
// C++/WinRT relay and realized through the WinUI host's registration of an
// application's own controls. A package of its own because WebView2 needs a
// runtime the platform does not ship with WinUI: an application showing a web
// view on WinUI depends on it from its WinUI head and calls
// StateUIWebViewWinUI.register() before it runs. The relay includes the
// projection the WinUI host generated.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault"), .define("WINUI")]

let package = Package(
    name: "StateUIWebViewWinUI",
    products: [
        // Dynamic, as the WinUI host is: a head links it once beside the host.
        .library(name: "StateUIWebViewWinUI", type: .dynamic, targets: ["StateUIWebViewWinUI"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIHost", path: "../../StateUI/StateUI.Host"),
        .package(name: "StateUIWinUI", path: "../../StateUI/StateUI.WinUI"),
    ],
    targets: [
        // WinUI's WebView2, C++/WinRT behind C functions.
        .target(
            name: "CWebViewWinUI",
            path: "Relay",
            cxxSettings: [.unsafeFlags(["-I", Context.packageDirectory + "/../../StateUI/StateUI.WinUI/.projection"])],
            linkerSettings: [.linkedLibrary("shcore"), .linkedLibrary("shlwapi")]
        ),
        .target(
            name: "StateUIWebViewWinUI",
            dependencies: [
                "CWebViewWinUI",
                .product(name: "StateUIHost", package: "StateUIHost"),
                .product(name: "StateUIWinUI", package: "StateUIWinUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
            ],
            path: "Sources/StateUIWebViewWinUI", swiftSettings: settings),
    ],
    cxxLanguageStandard: .cxx20
)
