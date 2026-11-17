// swift-tools-version:6.4
import PackageDescription

// The Gallery's Android head: the library Android loads, with OpenGL ES for the cube. It builds the application,
// ../.., with the trait Android, which defines the application's `#if ANDROID`, and brings the host through
// StateUIHead; it imports StateUI and the host by name.
let package = Package(
    name: "GalleryAndroid",
    products: [.library(name: "GalleryAndroid", type: .dynamic, targets: ["GalleryAndroid"])],
    dependencies: [
        .package(name: "GalleryUI", path: "../..", traits: ["Android"]),
        .package(name: "StateUIRoot", path: "../../../.."),
        .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["Android"]),
    ],
    targets: [
        .target(
            name: "GalleryAndroid",
            dependencies: [
                .product(name: "GalleryUI", package: "GalleryUI"),
                .product(name: "StateUI", package: "StateUIRoot"),
                .product(name: "StateUIHead", package: "StateUIHead"), "CGalleryGLES",
            ],
            path: "Swift",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"), .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        // OpenGL ES 3.0 for the cube: EGL, GLES3 and the NDK's window of a Java Surface.
        .systemLibrary(name: "CGalleryGLES", path: "GLES"),
    ]
)
