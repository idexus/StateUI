// swift-tools-version:6.4
import PackageDescription

// HelloWorld's Web head: the module the page runs, compiled to WebAssembly, which links StateUI static. It builds the
// application, ../.., with the trait Web, which defines the application's `#if WEB`, and brings the host through
// StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "HelloWorldWeb",
    dependencies: [
        .package(name: "HelloWorldUI", path: "../..", traits: ["Web"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["Web"]),
    ],
    targets: [
        .executableTarget(
            name: "HelloWorldWeb",
            dependencies: [
                .product(name: "HelloWorldUI", package: "HelloWorldUI"),
                .product(name: "StateUIStatic", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"),
            ],
            path: ".", exclude: ["Package.swift"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
