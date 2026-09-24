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

// WHETHER THIS BUILD HAS AN ANDROID HEAD - the same question for the Android
// Views host, asked by .scripts/Android/build-swift.sh.
let hasAndroidHead = ProcessInfo.processInfo.environment["STATEUI_ANDROID"] == "1"

// WHETHER THIS BUILD HAS A WINUI HEAD - the same question for the WinUI 3
// host, asked by .scripts/WinUI/run-app.ps1.
let hasWinUIHead = ProcessInfo.processInfo.environment["STATEUI_WINUI"] == "1"

// What every module of the application is compiled with - in an AppKit build
// including APPKIT, in an Android Views build ANDROID, in a WinUI build WINUI,
// each defined here and nowhere else. See apps/Gallery/Package.swift.
let settings: [SwiftSetting] =
    [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    + (hasAppKitHead ? [.define("APPKIT")] : [])
    + (hasAndroidHead ? [.define("ANDROID")] : [])
    + (hasWinUIHead ? [.define("WINUI")] : [])

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
    //     .package(url: "https://github.com/idexus/StateUI.git", exact: "0.4.0")
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

if hasAndroidHead {
    // The same Swift application, loaded by Android as a library: its
    // JNI_OnLoad names the application to the Android Views host.
    products.append(
        .library(
            name: "HelloWorldAndroid",
            type: .dynamic,
            targets: ["HelloWorldAndroid"]
        ))

    dependencies.append(
        .package(name: "StateUIAndroid", path: "../../lib/StateUI.Android"))

    targets.append(
        .target(
            name: "HelloWorldAndroid",
            dependencies: [
                "HelloWorldUI",
                .product(name: "StateUIAndroid", package: "StateUIAndroid"),
            ],
            path: "Platforms/Android/Swift",
            swiftSettings: settings
        ))
}

if hasWinUIHead {
    // The same Swift application, an executable its WinUI host runs on
    // Windows: its main names the application to the host and hands it the thread.
    products.append(
        .executable(
            name: "HelloWorldWinUI",
            targets: ["HelloWorldWinUI"]
        ))

    dependencies.append(
        .package(name: "StateUIWinUI", path: "../../lib/StateUI.WinUI"))

    targets.append(
        .executableTarget(
            name: "HelloWorldWinUI",
            dependencies: [
                "HelloWorldUI",
                .product(name: "StateUIWinUI", package: "StateUIWinUI"),
            ],
            path: "Platforms/WinUI",
            swiftSettings: settings
        ))
}

let package = Package(
    name: "HelloWorldUI",
    // The same floor StateUI declares. SwiftPM refuses a package that depends
    // on one requiring more than it does, so these move together - see the note
    // in ../../Package.swift for what fixes them at 26.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: products,
    dependencies: dependencies,
    targets: targets
)
