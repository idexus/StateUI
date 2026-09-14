// swift-tools-version:6.0
import PackageDescription

// The application's own Swift module.
//
// Beside Sources/, so SwiftPM keeps .build/ and Package.resolved out of the
// source tree while the application code remains grouped below Sources/.
//
// WHY THIS FILE EXISTS:
// SourceKit - the language server behind Swift support in VS Code and Xcode -
// only understands code that belongs to a SwiftPM package. Without a manifest it
// reports "No such module 'StateUI'" and offers no completion, even though the
// build itself works fine, because the build scripts pass -I explicitly.
//
// GalleryUI is the platform-neutral application module. Executable host targets
// import it and select a native renderer without changing the application's UI.
let package = Package(
    name: "GalleryUI",
    // The same floor StateUI declares. SwiftPM refuses a package that depends
    // on one requiring more than it does, so these move together - see the note
    // in ../../Package.swift for what fixes them at 17.
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
    ],
    products: [
        // Dynamic so an executable and its host share exactly one StateUI
        // runtime and therefore one set of global runtime types.
        .library(
            name: "GalleryUI",
            type: .dynamic,
            targets: ["GalleryUI"]
        ),
        // The same gallery module above, launched directly by its AppKit host.
        .executable(
            name: "GalleryAppKit",
            targets: ["GalleryAppKit"]
        ),
    ],
    dependencies: [
        // A path dependency on the REPOSITORY ROOT, which is where the library's
        // manifest lives. An app outside this repository writes the published
        // package instead, and changes nothing else:
        //
        //     .package(url: "https://github.com/idexus/StateUI.git", exact: "0.3.1")
        .package(path: "../.."),
        .package(name: "StateUIAppKit", path: "../../lib/StateUI.AppKit"),
    ],
    targets: [
        .target(
            name: "GalleryUI",
            // Named WITHOUT `package:`. A path dependency's identity is the
            // last component of its path, so naming it would tie this manifest
            // to the checkout being called "StateUI" - and a zip from GitHub
            // unpacks as "StateUI-main". A bare name is looked for among every
            // dependency's products, and reads the same against the published
            // package.
            dependencies: ["StateUI"],
            // path: "Sources" - that whole folder is the app's code: the
            // application and its pages sit directly in it, Styles/ holds the
            // styles, and a directory added beside them is compiled without
            // being named here. Naming the folder rather than "." is what lets
            // the manifest sit beside the source and Resources/ without pulling
            // either host or artwork into the application module.
            path: "Sources",
            // The one setting an application must not leave out - see the note
            // in ../../Package.swift. Handlers carry the library's executor;
            // an `async func` written here must inherit its caller's executor too.
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .executableTarget(
            name: "GalleryAppKit",
            dependencies: [
                "GalleryUI",
                .product(name: "StateUIAppKit", package: "StateUIAppKit"),
            ],
            path: "Platforms/AppKit",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "GalleryTests",
            dependencies: [
                "GalleryUI",
                .product(name: "StateUI", package: "StateUI"),
            ],
            path: "Tests/GalleryTests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
