// swift-tools-version:6.4
import PackageDescription

// HelloWorld's WinUI head: the program WinUI runs. It builds the application, ../.., with the trait WinUI, which
// defines the application's `#if WINUI`, and brings the host through StateUIHead; it imports StateUI and the host by
// name.
let package = Package(
    name: "HelloWorldWinUI",
    dependencies: [
        .package(name: "HelloWorldUI", path: "../..", traits: ["WinUI"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["WinUI"]),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorldWinUI",
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
