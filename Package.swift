// swift-tools-version:6.0
import PackageDescription

// The StateUI library.
//
// A self-contained Swift package: it knows nothing about any particular
// application, which is what allows it to be published and consumed on its own.
// An app provides its UI in a separate module that DEPENDS on this one - see
// apps/Gallery/Swift/ in this repository for an example.
//
// AT THE REPOSITORY ROOT, which is not a matter of taste: SwiftPM reads a
// package's manifest from the root of the checkout and nowhere else, so this is
// the one place it can sit if anybody is to write
//
//     .package(url: "https://github.com/idexus/StateUI.git", exact: "0.3.0")
//
// The code stays under src/StateUI/ regardless, which is what the paths below
// say - Swift and C# still never share a directory.
//
// This manifest is used directly for Android, where cross-compilation goes
// through a Swift SDK - a SwiftPM feature that swiftc knows nothing about. Apple
// and Windows invoke swiftc directly, since there cross-compilation is a matter
// of -target/-sdk flags.
//
// Sources are never listed: SwiftPM globs the target's path, and the build
// scripts glob the same tree. A new .swift file is picked up by both.
let package = Package(
    name: "StateUI",
    // Must match IOS_MIN/CATALYST_MIN in .scripts/build-apple.sh and
    // SupportedOSPlatformVersion in the app project. A custom SerialExecutor -
    // Core/MainThread.swift, which is what puts a resumed handler back on the
    // thread MAUI draws on - is iOS 17 API.
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "StateUI",
            type: .dynamic,
            targets: ["StateUI"]
        ),
    ],
    // NO DEPENDENCIES, and it is worth a sentence: everything here is this
    // library's own code - state, the differ, the wire, the views. A class's
    // properties are state by wearing `@State`, which is a property wrapper
    // like the one a view uses and needs no compiler plugin, so a cold build
    // compiles this package and nothing else.
    targets: [
        // path: "src/StateUI/Sources" rather than the default
        // Sources/StateUI/.
        //
        // SwiftPM looks for Sources/<TargetName>/ unless told otherwise. The
        // code lives beside the C# runtime it is rendered by, one directory per
        // language, and stating the path is what lets the manifest sit at the
        // root without dragging the sources up with it.
        //
        // NonisolatedNonsendingByDefault (SE-0461) is the reason for
        // swiftSettings, and it is set wherever Swift is compiled here - the two
        // other manifests and both build scripts. Without it a plain `async`
        // function runs on Swift's cooperative pool whoever calls it, so a
        // handler awaiting one resumes off the thread MAUI draws on. The library
        // says `nonisolated(nonsending)` on its own six regardless; the flag is
        // what extends that to the functions an APPLICATION writes, which no
        // annotation of ours can reach. It becomes the default in Swift 7.
        .target(
            name: "StateUI",
            path: "src/StateUI/Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        )
    ]
)
