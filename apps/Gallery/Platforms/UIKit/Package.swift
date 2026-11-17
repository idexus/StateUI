// swift-tools-version:6.4
import PackageDescription

// The Gallery's UIKit head: the program UIKit runs; its own Info.plist keys join its bundle's. It builds the
// application, ../.., with the trait UIKit, which defines the application's `#if UIKIT`, and brings the host through
// StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "GalleryUIKit",
    platforms: [.iOS("26.4")],
    dependencies: [
        .package(name: "GalleryUI", path: "../..", traits: ["UIKit"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["UIKit"]),
    ],
    targets: [
        .executableTarget(
            name: "GalleryUIKit",
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
