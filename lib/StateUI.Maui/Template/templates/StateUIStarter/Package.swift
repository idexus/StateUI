// swift-tools-version:6.4
//#if (AppKit)
import Foundation
//#endif
import PackageDescription

//#if (AppKit && !UseCheckout)
#error("The AppKit host is built from a StateUI checkout: create the application with --stateui-path as well as --appkit.")
//#endif
// The application's own Swift module, which every head of this application
// compiles: the MAUI project in Platforms/Maui builds it for each of its
// platforms through StateUI's build, and the AppKit executable in
// Platforms/AppKit - where the application has one - launches it on macOS.
//
// WHY THIS FILE EXISTS:
// SourceKit - the language server behind Swift support in VS Code and Xcode -
// only understands code that belongs to a SwiftPM package. Without a manifest it
// reports "No such module 'StateUI'" and offers no completion. It also does real
// work: the Android and Linux builds use this package directly, since
// cross-compiling with a Swift SDK is a SwiftPM feature.
//
// THE MODULE NAME MUST MATCH $(StateUIAppModule) in MSBuild, which defaults to
// the MAUI project's name plus "UI" - StateUIStarter becomes StateUIStarterUI.
// The build verifies this and fails with a clear message if the two drift
// apart.

//#if (AppKit)
// WHETHER THIS BUILD HAS AN APPKIT HEAD.
//
// Platforms/AppKit is one host's half and nothing else has any business
// compiling it: it imports StateUIAppKit, and it may be written against
// elements this application declares for that host alone. So the target, the
// product it makes and the dependency it needs are declared only when an
// AppKit build asks for them, and `swift test` neither resolves that package
// nor compiles a line of that folder.
//
// AN ENVIRONMENT VARIABLE, because a manifest cannot read a compilation
// condition: a flag given to a build reaches its targets and never the
// manifest that describes them. .vscode/tasks.json sets it for the build and
// .vscode/settings.json for the editor.
let hasAppKitHead = ProcessInfo.processInfo.environment["STATEUI_APPKIT"] == "1"

// What every module of the application is compiled with. In an AppKit build
// that includes APPKIT, the condition Swift written for that host alone stands
// under - defined here, so the one variable says both things and an editor
// that sets it completes the code inside `#if APPKIT` like any other.
let settings: [SwiftSetting] =
    [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    + (hasAppKitHead ? [.define("APPKIT")] : [])

//#else
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]

//#endif
var products: [Product] = [
    // Dynamic, so a head and the library share exactly one StateUI runtime.
    .library(
        name: "StateUIStarterUI",
        type: .dynamic,
        targets: ["StateUIStarterUI"]
    ),
]

var dependencies: [Package.Dependency] = [
//#if (UseCheckout)
    // A StateUI checkout on disk. The MAUI project reads the C# half from
    // the same checkout, so the two halves of the wire move together.
    .package(path: "STATEUI_CHECKOUT"),
//#else
    // THE SWIFT HALF OF StateUI. Its C# half is the NuGet package named in
    // Platforms/Maui/StateUIStarter.csproj, and the two move together: the
    // wire between them is a binary contract, so the version here IS the
    // version there.
    .package(url: "https://github.com/idexus/StateUI.git", exact: "0.4.0"),
//#endif
]

var targets: [Target] = [
    .target(
        name: "StateUIStarterUI",
        // Named WITHOUT `package:`: a path dependency's identity is the
        // last component of its path, and a bare name is looked for among
        // every dependency's products, whatever the checkout is called.
        dependencies: ["StateUI"],
        // The whole folder is the application's code: the application and
        // its pages sit directly in it and Styles/ holds the styles.
        path: "Sources",
        // A plain `async` function written here resumes on its caller's
        // executor rather than on Swift's cooperative pool.
        swiftSettings: settings
    ),
]

//#if (AppKit)
if hasAppKitHead {
    // The same module, launched directly by its AppKit host.
    products.append(
        .executable(
            name: "StateUIStarterAppKit",
            targets: ["StateUIStarterAppKit"]
        ))

    dependencies.append(
        .package(name: "StateUIAppKit", path: "STATEUI_CHECKOUT/lib/StateUI.AppKit"))

    targets.append(
        .executableTarget(
            name: "StateUIStarterAppKit",
            dependencies: [
                "StateUIStarterUI",
                .product(name: "StateUIAppKit", package: "StateUIAppKit"),
            ],
            path: "Platforms/AppKit",
            swiftSettings: settings
        ))
}

//#endif
let package = Package(
    name: "StateUIStarterUI",
    // The same floor StateUI declares, and it must not go below it: SwiftPM
    // refuses a package that depends on one requiring more than it does.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: products,
    dependencies: dependencies,
    targets: targets
)
