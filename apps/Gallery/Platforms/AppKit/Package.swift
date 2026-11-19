// swift-tools-version:6.4
import PackageDescription

// The Gallery's AppKit head: the program AppKit runs; its own Info.plist keys join its bundle's. It builds the
// application, ../.., with the trait AppKit, which defines the application's `#if APPKIT`, and brings the host
// through StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "GalleryAppKit",
    platforms: [.macOS("26.4")],
    dependencies: [
        .package(name: "GalleryUI", path: "../..", traits: ["AppKit"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["AppKit"]),
    ],
    targets: [
        .executableTarget(
            name: "GalleryAppKit",
            dependencies: [
                .product(name: "GalleryUI", package: "GalleryUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"),
            ],
            path: ".", exclude: ["Package.swift", "Info.plist"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
