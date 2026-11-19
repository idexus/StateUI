// swift-tools-version:6.4
import PackageDescription

// The Gallery's WinUI head: the program WinUI runs, with WebView2's web view and the gallery's own elements. It
// builds the application, ../.., with the trait WinUI, which defines the application's `#if WINUI`, and brings the
// host through StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "GalleryWinUI",
    dependencies: [
        .package(name: "GalleryUI", path: "../..", traits: ["WinUI"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["WinUI"]),
        .package(name: "StateUIWebViewWinUI", path: "../../../../lib/Backends/WebView.WinUI"),
    ],
    targets: [
        .executableTarget(
            name: "GalleryWinUI",
            dependencies: [
                .product(name: "GalleryUI", package: "GalleryUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"),
                .product(name: "StateUIWebViewWinUI", package: "StateUIWebViewWinUI"), "CGalleryWinUI",
            ],
            path: ".", exclude: ["Package.swift", "Relay"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        // The gallery's own WinUI elements, C++/WinRT behind C functions: the traffic light, the rating bar, the cube
        // Direct3D 11.1 draws, and the battery. It includes the projection the WinUI host generated.
        .target(
            name: "CGalleryWinUI",
            path: "Relay",
            // Design: docs/design/platforms/winui/relay.md#the-compiler-the-library-expects
            cxxSettings: [
                .unsafeFlags(["-I", Context.packageDirectory + "/../../../../lib/StateUI/StateUI.WinUI/.projection"]),
                .define("_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH"),
            ],
            linkerSettings: [
                .linkedLibrary("d3d11"), .linkedLibrary("dxgi"), .linkedLibrary("d3dcompiler"),
                .linkedLibrary("powrprof"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
