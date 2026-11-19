// swift-tools-version:6.4
import PackageDescription

// The Gallery's GTK head: the program GTK runs, with WebKitGTK's web view and OpenGL for the cube. It builds the
// application, ../.., with the trait GTK, which defines the application's `#if GTK`, and brings the host through
// StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "GalleryGTK",
    dependencies: [
        .package(name: "GalleryUI", path: "../..", traits: ["GTK"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["GTK"]),
        .package(name: "StateUIWebViewGTK", path: "../../../../lib/Backends/WebView.GTK"),
    ],
    targets: [
        .executableTarget(
            name: "GalleryGTK",
            dependencies: [
                .product(name: "GalleryUI", package: "GalleryUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"),
                .product(name: "StateUIWebViewGTK", package: "StateUIWebViewGTK"), "CGalleryOpenGL",
            ],
            path: ".", exclude: ["Package.swift", "OpenGL", "link-schemes"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        // OpenGL for the cube, through libepoxy - the loader GTK itself draws with.
        .systemLibrary(name: "CGalleryOpenGL", path: "OpenGL", pkgConfig: "epoxy"),
    ]
)
