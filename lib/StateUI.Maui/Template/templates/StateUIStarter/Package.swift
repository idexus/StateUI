// swift-tools-version:6.0
import PackageDescription

//#if (AppKit && !UseCheckout)
#error("The AppKit host is built from a StateUI checkout: create the application with --stateui-path as well as --appkit.")
//#endif
// The application's own Swift module, which every head of this application
// compiles: the MAUI project in Platforms/Maui builds it for each of its
// platforms through .scripts/Maui, and the AppKit executable in
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
let package = Package(
    name: "StateUIStarterUI",
    // The same floor StateUI declares, and it must not go below it: SwiftPM
    // refuses a package that depends on one requiring more than it does.
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
    ],
    products: [
        // Dynamic, so a head and the library share exactly one StateUI runtime.
        .library(
            name: "StateUIStarterUI",
            type: .dynamic,
            targets: ["StateUIStarterUI"]
        ),
//#if (AppKit)
        // The same module, launched directly by its AppKit host.
        .executable(
            name: "StateUIStarterAppKit",
            targets: ["StateUIStarterAppKit"]
        ),
//#endif
    ],
    dependencies: [
//#if (UseCheckout)
        // A StateUI checkout on disk. The MAUI project reads the C# half from
        // the same checkout, so the two halves of the wire move together.
        .package(path: "STATEUI_CHECKOUT"),
//#else
        // THE SWIFT HALF OF StateUI. Its C# half is the NuGet package named in
        // Platforms/Maui/StateUIStarter.csproj, and the two move together: the
        // wire between them is a binary contract, so the version here IS the
        // version there.
        .package(url: "https://github.com/idexus/StateUI.git", exact: "0.3.1"),
//#endif
//#if (AppKit)
        .package(name: "StateUIAppKit", path: "STATEUI_CHECKOUT/lib/StateUI.AppKit"),
//#endif
    ],
    targets: [
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
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
//#if (AppKit)
        .executableTarget(
            name: "StateUIStarterAppKit",
            dependencies: [
                "StateUIStarterUI",
                .product(name: "StateUIAppKit", package: "StateUIAppKit"),
            ],
            path: "Platforms/AppKit",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
//#endif
    ]
)
