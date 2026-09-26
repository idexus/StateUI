// swift-tools-version:6.4
import PackageDescription

// The StateUI library.
//
// A self-contained Swift package: it knows nothing about any particular
// application, which is what allows it to be published and consumed on its own.
// An app provides its UI in a separate module that DEPENDS on this one - see
// apps/Gallery/Sources/ in this repository for an example.
//
// AT THE REPOSITORY ROOT, which is not a matter of taste: SwiftPM reads a
// package's manifest from the root of the checkout and nowhere else, so this is
// the one place it can sit if anybody is to write
//
//     .package(url: "https://github.com/idexus/StateUI.git", exact: "0.4.0")
//
// The code stays under lib/StateUI/ regardless, which is what the paths below
// say. Native host packages remain siblings so their platform dependencies do
// not enter the cross-platform core.
//
// Sources are never listed: SwiftPM globs the target's path, and the build
// scripts glob the same tree. A new .swift file is picked up by both.
let package = Package(
    name: "StateUI",
    // iOS 26, Mac Catalyst 26 and macOS 26: the releases StateUI is built and
    // tested against, with Xcode 27.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
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
        // path: "lib/StateUI/Sources" rather than the default
        // Sources/StateUI/.
        //
        // SwiftPM looks for Sources/<TargetName>/ unless told otherwise. The
        // code stays under lib/, and stating the path lets the manifest remain
        // at the repository root without moving the sources.
        //
        // NonisolatedNonsendingByDefault (SE-0461) is the reason for
        // swiftSettings, and it is set wherever Swift is compiled here - the two
        // other manifests and both build scripts. Without it a plain `async`
        // function runs on Swift's cooperative pool whoever calls it, so a
        // handler awaiting one resumes away from its caller's executor. The library
        // says `nonisolated(nonsending)` on its own six regardless; the flag is
        // what extends that to the functions an APPLICATION writes, which no
        // annotation of ours can reach. It becomes the default in Swift 7.
        .target(
            name: "StateUI",
            path: "lib/StateUI/Sources",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUITests",
            dependencies: ["StateUI"],
            path: "lib/StateUI/Tests",
            // HostConformance beside it is a package of its own, which the hosts' suites link.
            exclude: ["HostConformance"],
            sources: ["StateUITests"],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
