// swift-tools-version:6.0
import PackageDescription

// The application's own Swift module.
//
// BESIDE THE .csproj, not inside Swift/. Both files describe how this app is
// built, and SwiftPM writes .build/ and Package.resolved next to whichever
// directory holds the manifest - so keeping it here leaves Swift/ as nothing
// but source, and puts the build products where bin/ and obj/ already are.
//
// WHY THIS FILE EXISTS:
// SourceKit - the language server behind Swift support in VS Code and Xcode -
// only understands code that belongs to a SwiftPM package. Without a manifest it
// reports "No such module 'StateUI'" and offers no completion, even though the
// build itself works fine, because the build scripts pass -I explicitly.
//
// It also does real work: the Android build uses this package directly, since
// cross-compiling with a Swift SDK is a SwiftPM feature that swiftc has no
// equivalent for.
//
// THE MODULE NAME MUST MATCH $(StateUIAppModule) in MSBuild, which defaults to
// the project name plus "UI" - Gallery becomes GalleryUI. The build
// verifies this and fails with a clear message if the two drift apart, because
// the mismatch would otherwise surface much later as a missing native library.
//
// Copying this app as a starting point? Rename the target and product below to
// match the new project name, or set StateUIAppModule in the .csproj.
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
        // .dynamic to match how the library is built: on Android both are
        // separate .so files, with the app's linking against StateUI.
        .library(
            name: "GalleryUI",
            type: .dynamic,
            targets: ["GalleryUI"]
        ),
    ],
    dependencies: [
        // A path dependency on the REPOSITORY ROOT, which is where the library's
        // manifest lives. An app outside this repository writes the published
        // package instead, and changes nothing else:
        //
        //     .package(url: "https://github.com/idexus/StateUI.git", exact: "0.2.0")
        .package(path: "../.."),
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
            // path: "Swift" - that whole folder is the app's code: the
            // application and its pages sit directly in it, Styles/ holds the
            // styles, and a directory added beside them is compiled without
            // being named here. Naming the folder rather than "." is what lets
            // the manifest sit beside the .csproj: everything else at this
            // level - Host/, Platforms/, Resources/, bin/, obj/ - is not Swift
            // and is not the target's to look at.
            path: "Swift",
            // The one setting an application must not leave out - see the note
            // in ../../Package.swift. Handlers are safe either way,
            // their type coming from the library; an `async func` written HERE
            // is not, and would resume off the thread MAUI draws on.
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
