// swift-tools-version:6.4
import PackageDescription

// The application's own Swift module, GalleryUI, its acceptance tests, and its
// head for the host a build is for. SourceKit understands only code a SwiftPM
// package holds, so the editor completes the application through this
// manifest as well.

// The host a build is for: the STATEUI_ variable its script or the editor sets,
// or none for plain Swift - and then `swift test` compiles no line of any
// host's half. The application's Swift for that host alone stands under its
// condition - `#if APPKIT` - and ../../lib/StateUI.Head brings the host itself
// to the head.
let host = ["AppKit", "UIKit", "Android", "WinUI", "GTK"]
    .first { Context.environment["STATEUI_\($0.uppercased())"] == "1" }

// NonisolatedNonsendingByDefault is the one setting an application must not
// leave out; see the note in ../../Package.swift.
let settings: [SwiftSetting] = [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]
    + (host.map { [.define($0.uppercased())] } ?? [])

var products: [Product] = [
    // Dynamic, so a head and its host share one StateUI runtime.
    .library(name: "GalleryUI", type: .dynamic, targets: ["GalleryUI"]),
]

var targets: [Target] = [
    .target(name: "GalleryUI", dependencies: ["StateUI"], path: "Sources", swiftSettings: settings),
    .testTarget(
        name: "GalleryTests",
        dependencies: ["GalleryUI", .product(name: "StateUI", package: "StateUI")],
        path: "Tests/GalleryTests",
        swiftSettings: settings
    ),
]

// The head in Platforms/<Host>: an executable its host runs, and on Android a
// library the platform loads. StateUIHead brings the host; the gallery's cube
// adds a native module to three of them.
let head: [Target.Dependency] = ["GalleryUI", .product(name: "StateUIHead", package: "StateUIHead")]
switch host {
case "Android"?:
    products.append(.library(name: "GalleryAndroid", type: .dynamic, targets: ["GalleryAndroid"]))
    targets.append(contentsOf: [
        .target(
            name: "GalleryAndroid", dependencies: head + ["CGalleryGLES"],
            path: "Platforms/Android/Swift", swiftSettings: settings),
        // OpenGL ES 3.0 for the cube: EGL, GLES3 and the NDK's window of a Java Surface.
        .systemLibrary(name: "CGalleryGLES", path: "Platforms/Android/GLES"),
    ])
case "WinUI"?:
    targets.append(contentsOf: [
        .executableTarget(
            name: "GalleryWinUI", dependencies: head + ["CGalleryWinUI"],
            path: "Platforms/WinUI", exclude: ["Relay"], swiftSettings: settings),
        // The gallery's own WinUI elements, C++/WinRT behind C functions: the traffic light, the rating bar, the
        // cube Direct3D 11.1 draws, and the battery. It includes the projection the WinUI host generated.
        .target(
            name: "CGalleryWinUI",
            path: "Platforms/WinUI/Relay",
            cxxSettings: [
                .unsafeFlags(["-I", Context.packageDirectory + "/../../lib/StateUI.WinUI/.projection"]),
            ],
            linkerSettings: [
                .linkedLibrary("d3d11"), .linkedLibrary("dxgi"), .linkedLibrary("d3dcompiler"),
                .linkedLibrary("powrprof"),
            ]
        ),
    ])
case "GTK"?:
    targets.append(contentsOf: [
        .executableTarget(
            name: "GalleryGTK", dependencies: head + ["CGalleryOpenGL"],
            path: "Platforms/GTK", exclude: ["OpenGL"], swiftSettings: settings),
        // OpenGL for the cube, through libepoxy - the loader GTK itself draws with.
        .systemLibrary(name: "CGalleryOpenGL", path: "Platforms/GTK/OpenGL", pkgConfig: "epoxy"),
    ])
case let host?:
    targets.append(.executableTarget(
        name: "Gallery\(host)", dependencies: head, path: "Platforms/\(host)", swiftSettings: settings))
case nil:
    break
}

let package = Package(
    name: "GalleryUI",
    // StateUI's floor, which an application cannot go below.
    platforms: [
        .iOS(.v26),
        .macCatalyst(.v26),
        .macOS(.v26),
    ],
    products: products,
    // The StateUI checkout: the library at its root, and a head's host.
    dependencies: [.package(path: "../..")]
        + (host == nil ? [] : [.package(name: "StateUIHead", path: "../../lib/StateUI.Head")]),
    targets: targets,
    cxxLanguageStandard: .cxx20
)
