// swift-tools-version:6.4
import PackageDescription

// The Gallery's Web head: the module the page runs, compiled to WebAssembly, which links StateUI static; its page
// scripts stand beside it. It builds the application, ../.., with the trait Web, which defines the application's `#if
// WEB`, and brings the host through StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "GalleryWeb",
    dependencies: [
        .package(name: "GalleryUI", path: "../..", traits: ["Web"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["Web"]),
    ],
    targets: [
        .executableTarget(
            name: "GalleryWeb",
            dependencies: [
                .product(name: "GalleryUI", package: "GalleryUI"),
                .product(name: "StateUIStatic", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"),
            ],
            path: ".", exclude: ["Package.swift", "Page"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
