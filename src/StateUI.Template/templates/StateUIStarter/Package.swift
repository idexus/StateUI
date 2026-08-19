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
// the project name plus "UI" - StateUIStarter becomes StateUIStarterUI. The
// build verifies this and fails with a clear message if the two drift apart,
// because the mismatch would otherwise surface much later as a missing native
// library. Renaming the project therefore means renaming the package, the
// product and the target below - or setting StateUIAppModule in the .csproj.
let package = Package(
    name: "StateUIStarterUI",
    // The same floor StateUI declares, and it must not go below it: SwiftPM
    // refuses a package that depends on one requiring more than it does. 17
    // because a custom SerialExecutor - what puts a resumed handler back on the
    // thread MAUI draws on - is iOS 17 API. It also matches
    // SupportedOSPlatformVersion in the .csproj.
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
    ],
    products: [
        // .dynamic to match how the library is built: on Android both are
        // separate .so files, with the app's linking against StateUI.
        .library(
            name: "StateUIStarterUI",
            type: .dynamic,
            targets: ["StateUIStarterUI"]
        ),
    ],
    dependencies: [
        // THE SWIFT HALF OF StateUI. Its C# half is the NuGet package named
        // in the .csproj, and the two move together: the wire between them is
        // a binary contract, so the version here IS the version there - a
        // skew parks every await that crosses, with nothing reported.
        //
        // WORKING AGAINST A CHECKOUT ON DISK instead - a private repository, or
        // the library itself under development - takes two lines rather than
        // one, because a path dependency is never copied into .build/checkouts
        // where the build looks for the library's sources:
        //
        //     .package(path: "/path/to/StateUI"),
        //
        // and, in the .csproj beside this file:
        //
        //     <StateUIPackagePath>/path/to/StateUI/</StateUIPackagePath>
        .package(url: "https://github.com/idexus/StateUI.git", exact: "0.1.0"),
    ],
    targets: [
        .target(
            name: "StateUIStarterUI",
            // Named WITHOUT `package:`, which is not shorthand: a dependency's
            // identity is derived from its URL or path, so naming it would tie
            // this line to how the library was reached. A bare name is looked
            // for among every dependency's products instead, and reads the same
            // whichever of the three forms above is in use.
            dependencies: ["StateUI"],
            // path: "Swift" - that whole folder is the app's code: the
            // application and its pages sit directly in it, Styles/ holds the
            // styles, and a directory added beside them is compiled without
            // being named here. Naming the folder rather than "." is what lets
            // the manifest sit beside the .csproj: everything else at this
            // level - Host/, Platforms/, Resources/, bin/, obj/ - is not Swift
            // and is not the target's to look at.
            path: "Swift",
            // THE ONE SETTING AN APPLICATION MUST NOT LEAVE OUT. Handlers are
            // safe either way, their type coming from the library; an
            // `async func` written HERE is not - without this it runs on Swift's
            // cooperative pool, and a handler awaiting it resumes off the thread
            // MAUI draws on, with no diagnostic anywhere.
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
