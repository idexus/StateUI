// swift-tools-version:6.4
import PackageDescription

// HelloWorld's UIKit head: the program UIKit runs. It builds the application, ../.., with the trait UIKit, which
// defines the application's `#if UIKIT`, and brings the host through StateUIHead; it imports StateUI and the host by
// name.
let package = Package(
    name: "HelloWorldUIKit",
    platforms: [.iOS("26.4")],
    dependencies: [
        .package(name: "HelloWorldUI", path: "../..", traits: ["UIKit"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["UIKit"]),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorldUIKit",
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
