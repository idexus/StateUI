// swift-tools-version:6.4
import PackageDescription

// The Android Views host's tests. A view exists only in an application's
// process, so the tests are a library the test APK loads, run on the UI thread
// by its instrumentation - Platforms/Android beside this file.
// .scripts/Android/test-android.sh builds, installs and runs them.
let package = Package(
    name: "StateUIAndroidTests",
    products: [
        .library(name: "StateUIAndroidTests", type: .dynamic, targets: ["StateUIAndroidTests"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../../.."),
        .package(name: "StateUIAndroid", path: ".."),
    ],
    targets: [
        .target(
            name: "StateUIAndroidTests",
            dependencies: [
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIAndroid", package: "StateUIAndroid"),
            ],
            path: "Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
