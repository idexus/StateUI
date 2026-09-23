// swift-tools-version:6.4
import Foundation
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
// HelloWorldUI is the platform-neutral application module. Executable host
// targets import it and select a native renderer without changing the app UI.

// WHETHER THIS BUILD HAS AN APPKIT HEAD - the same question, and the same
// answer, as apps/Gallery/Package.swift. Platforms/AppKit is one host's half,
// it imports StateUIAppKit, and nothing else has any business compiling it; a
// manifest cannot read a compilation condition, which reaches a build's targets
// and never the manifest describing them, so an AppKit build says so here.
let hasAppKitHead = ProcessInfo.processInfo.environment["STATEUI_APPKIT"] == "1"

// What every module of the application is compiled with - in an AppKit build
// including APPKIT, defined here and nowhere else. See apps/Gallery/Package.swift.
let settings: [SwiftSetting] =
    [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    + (hasAppKitHead ? [.define("APPKIT")] : [])

var products: [Product] = [
    // Dynamic so an executable and its host share exactly one StateUI
    // runtime and therefore one set of global runtime types.
    .library(
        name: "HelloWorldUI",
        type: .dynamic,
        targets: ["HelloWorldUI"]
    ),
]

var dependencies: [Package.Dependency] = [
    // A path dependency on the REPOSITORY ROOT, which is where the library's
    // manifest lives. An app outside this repository writes the published
    // package instead, and changes nothing else:
    //
    //     .package(url: "https://github.com/idexus/StateUI.git", exact: "0.3.1")
    .package(path: "../.."),
]

var targets: [Target] = [
    .target(
        name: "HelloWorldUI",
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
        // in ../../Package.swift. Handlers are safe either way,
        // their type coming from the library; an `async func` written HERE
        // is not, and would resume away from its caller's executor.
        swiftSettings: settings
    ),
]

if hasAppKitHead {
    // The same Swift application above, launched by its AppKit host.
    products.append(
        .executable(
            name: "HelloWorldAppKit",
            targets: ["HelloWorldAppKit"]
        ))

    dependencies.append(
        .package(name: "StateUIAppKit", path: "../../lib/StateUI.AppKit"))

    targets.append(
        .executableTarget(
            name: "HelloWorldAppKit",
            dependencies: [
                "HelloWorldUI",
                .product(name: "StateUIAppKit", package: "StateUIAppKit"),
            ],
            path: "Platforms/AppKit",
            swiftSettings: settings
        ))
}

let package = Package(
    name: "HelloWorldUI",
    // The same floor StateUI declares. SwiftPM refuses a package that depends
    // on one requiring more than it does, so these move together - see the note
    // in ../../Package.swift for what fixes them at 17.
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
    ],
    products: products,
    dependencies: dependencies,
    targets: targets
)
