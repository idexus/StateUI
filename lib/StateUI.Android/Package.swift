// swift-tools-version:6.4
import PackageDescription

// The Android Views host: Swift in the application's process, reading the
// typed patch and calling the views through JNI. A sibling package, as the
// AppKit host is, so the one dynamic StateUI runtime is linked into the
// application rather than copied into a second library in the same process.
// It builds for Android alone: .scripts/Android/build-swift.sh names the Swift
// SDK and the triple.
let package = Package(
    name: "StateUIAndroid",
    products: [
        .library(name: "StateUIAndroid", type: .dynamic, targets: ["StateUIAndroid"]),
    ],
    dependencies: [
        .package(name: "StateUIRoot", path: "../.."),
    ],
    targets: [
        // The NDK's C surface: JNI, the main thread's looper, the display's
        // frames, the log.
        .target(
            name: "CStateUIAndroid",
            path: "Sources/CStateUIAndroid",
            linkerSettings: [.linkedLibrary("android"), .linkedLibrary("log")]
        ),
        .target(
            name: "StateUIAndroid",
            dependencies: ["CStateUIAndroid", .product(name: "StateUI", package: "StateUIRoot")],
            path: "Sources/StateUIAndroid",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
