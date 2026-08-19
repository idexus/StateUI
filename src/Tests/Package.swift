// swift-tools-version:6.0
import PackageDescription

// The Swift tests, in a package of their own.
//
// They cannot live in the library's package: SwiftPM refuses a target whose path
// is outside the package root, and the tests belong next to the C# ones rather
// than inside the thing they test. A separate manifest also keeps the published
// package free of a test target it would never build.
//
// Two targets, because there are two things to check: the LIBRARY, and the
// GALLERY's catalog of samples - a list that will rot as samples are added
// unless something insists that every one of them is complete and reachable.
//
// Run them with:  swift test --package-path src/Tests
let package = Package(
    name: "StateUITests",
    // The same floor the two packages under test declare.
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14),
    ],
    dependencies: [
        // The repository root, which is where the library's manifest lives - it
        // has to be there for anyone to depend on this by URL.
        .package(path: "../.."),
        // The gallery's own package: its manifest sits beside the .csproj, so
        // the app directory IS the package. SwiftPM takes a path dependency's
        // IDENTITY from the last component of that path, which is what the
        // product below has to name.
        .package(path: "../../apps/Gallery"),
    ],
    // Both targets carry the same swiftSettings as the packages under test - see
    // the note in ../../Package.swift. A test standing in for a host has to be
    // compiled the way a host is, or it would check the wrong semantics of the
    // very thing it is there to pin down.
    //
    // StateUI is named WITHOUT `package:`. A path dependency's identity is the
    // last component of "../.." - the name the repository is checked out under -
    // and a bare product name resolves while that identity matches the product.
    // A checkout under any other name (a GitHub zip unpacks as "StateUI-main")
    // fails with "product 'StateUI' required by package 'tests' not found" and
    // needs `.product(name:package:)` - which is why CI checks the repository
    // out into a directory called StateUI. The gallery is named the long way
    // because its product and its package are called different things -
    // GalleryUI in Gallery - and a bare name only resolves while those agree.
    targets: [
        // The test-side reader of the binary wire (Core/Wire.swift): both test
        // targets decode taken batches with it, and a testTarget cannot depend
        // on another testTarget, so it is a small plain target of its own. It
        // reads only the library's PUBLIC surface - PropValue - which is what
        // lets it be an ordinary import rather than a @testable one.
        .target(
            name: "StateUIWireProbe",
            dependencies: ["StateUI"],
            path: "StateUIWireProbe",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "StateUITests",
            dependencies: ["StateUI", "StateUIWireProbe"],
            path: "StateUITests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
        .testTarget(
            name: "GalleryTests",
            dependencies: [
                .product(name: "GalleryUI", package: "Gallery"),
                "StateUI",
                "StateUIWireProbe",
            ],
            path: "GalleryTests",
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
        ),
    ]
)
