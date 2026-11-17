// swift-tools-version:6.4
import PackageDescription

// HelloWorld's AppKit head: the program AppKit runs. It builds the application, ../.., with the trait AppKit, which
// defines the application's `#if APPKIT`, and brings the host through StateUIHead; it imports StateUI and the host by
// name.
let package = Package(
    name: "HelloWorldAppKit",
    platforms: [.macOS("26.4")],
    dependencies: [
        .package(name: "HelloWorldUI", path: "../..", traits: ["AppKit"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["AppKit"]),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorldAppKit",
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
