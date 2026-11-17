// swift-tools-version:6.4
import PackageDescription

// HelloWorld's Android head: the library Android loads. It builds the application, ../.., with the trait Android,
// which defines the application's `#if ANDROID`, and brings the host through StateUIHead; it imports StateUI and the
// host by name.
let package = Package(
    name: "HelloWorldAndroid",
    products: [.library(name: "HelloWorldAndroid", type: .dynamic, targets: ["HelloWorldAndroid"])],
    dependencies: [
        .package(name: "HelloWorldUI", path: "../..", traits: ["Android"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["Android"]),
    ],
    targets: [
        .target(
            name: "HelloWorldAndroid",
            dependencies: [
                .product(name: "HelloWorldUI", package: "HelloWorldUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"),
            ],
            path: "Swift",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
