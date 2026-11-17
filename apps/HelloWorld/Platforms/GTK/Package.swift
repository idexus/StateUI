// swift-tools-version:6.4
import PackageDescription

// HelloWorld's GTK head: the program GTK runs. It builds the application, ../.., with the trait GTK, which defines
// the application's `#if GTK`, and brings the host through StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "HelloWorldGTK",
    dependencies: [
        .package(name: "HelloWorldUI", path: "../..", traits: ["GTK"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["GTK"]),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorldGTK",
            dependencies: [
                .product(name: "HelloWorldUI", package: "HelloWorldUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"),
            ],
            path: ".", exclude: ["Package.swift"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
