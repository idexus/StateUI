// swift-tools-version:6.4
import PackageDescription

// Map: a component an application imports beside StateUI, so an application
// that shows no map links neither it nor a platform's map engine. It is laid
// out as StateUI is: this package knows no host - the view, its pins and their
// contracts, in Core - and beside it, each a package of its own,
// Map.Conformance holds the family and its revisions, and each host's backend
// will stand as Map.<Host>, which the application's head for that host depends
// on and registers before it runs. A package's folder's name is its identity,
// unique among every package.

// NonisolatedNonsendingByDefault, as every StateUI package; see ../../../Package.swift.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]

let stateUI: Target.Dependency = .product(name: "StateUI", package: "StateUIRoot")

let products: [Product] = [
    // Dynamic, so an application's module, its head and its backend share one copy of the view's types.
    .library(name: "StateUIMap", type: .dynamic, targets: ["StateUIMap"]),
]

let dependencies: [Package.Dependency] = [
    .package(name: "StateUIRoot", path: "../../.."),
]

let targets: [Target] = [
    .target(name: "StateUIMap", dependencies: [stateUI], path: "Core/Sources", swiftSettings: settings),
    .testTarget(name: "StateUIMapTests", dependencies: ["StateUIMap", stateUI], path: "Core/Tests", swiftSettings: settings),
]

let package = Package(
    name: "StateUIMap",
    // StateUI's floor, which a component cannot go below.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: products,
    dependencies: dependencies,
    targets: targets
)
