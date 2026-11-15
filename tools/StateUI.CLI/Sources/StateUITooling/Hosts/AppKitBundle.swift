// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import Foundation
import StateUIToolingProtocol

/// An application's AppKit bundle, assembled from what SwiftPM built: `<Product>.app` with the head and the
/// libraries beside it in `MacOS`, the application's `Resources/Images` and its icon in `Resources`, `Info.plist`
/// from the host's keys and the application's own `Platforms/AppKit/Info.plist`, signed ad hoc.
/// Design: docs/design/tooling/apple-bundles.md#an-appkit-bundle
public struct AppKitBundle: Sendable {
    /// The application's folder: its `Resources` and `Platforms/AppKit`.
    public var application: URL
    /// The application's name: `Gallery`.
    public var name: String
    /// The product SwiftPM built: `GalleryAppKit`.
    public var product: String
    /// The folder SwiftPM laid the product and the libraries in (`--show-bin-path`).
    public var binaries: URL
    /// StateUI's release, the bundle's version.
    public var release: String
    /// The oldest macOS the bundle runs on.
    public var minimumSystem: String

    /// The bundle of `application`'s `product` as SwiftPM laid it in `binaries`.
    public init(application: URL, name: String, product: String, binaries: URL, release: String, minimumSystem: String) {
        self.application = application
        self.name = name
        self.product = product
        self.binaries = binaries
        self.release = release
        self.minimumSystem = minimumSystem
    }

    /// The bundle's folder's path within the artifact, and its program's.
    public var bundlePath: String { "\(product).app" }
    public var programPath: String { "\(product).app/Contents/MacOS/\(product)" }

    /// Assembles the bundle in `staging` - signed where `sign` - and answers its folder.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where `iconutil` or `codesign` refused.
    public func assemble(in staging: URL, sign: Bool = true) async throws -> URL {
        let files = FileManager.default
        let bundle = staging.appendingPathComponent(bundlePath)
        let contents = bundle.appendingPathComponent("Contents")
        let program = contents.appendingPathComponent("MacOS")
        let resources = contents.appendingPathComponent("Resources")
        try files.createDirectory(at: program, withIntermediateDirectories: true)
        try files.createDirectory(at: resources, withIntermediateDirectories: true)

        try files.copyItem(at: binaries.appendingPathComponent(product), to: program.appendingPathComponent(product))
        for library in try files.contentsOfDirectory(atPath: binaries.path).sorted() where library.hasSuffix(".dylib") {
            try files.copyItem(at: binaries.appendingPathComponent(library), to: program.appendingPathComponent(library))
        }
        let images = application.appendingPathComponent("Resources/Images")
        if files.fileExists(atPath: images.path) {
            try files.copyItem(at: images, to: resources.appendingPathComponent("Images"))
        }

        var keys = InfoPlist.macOS(name: name, product: product, release: release, minimumSystem: minimumSystem)
        let icon = application.appendingPathComponent("Resources/AppIcon/appicon_macos.svg")
        if files.fileExists(atPath: icon.path) {
            let iconset = staging.appendingPathComponent("StateUI.iconset")
            defer { try? files.removeItem(at: iconset) }
            try await Pictures(renderer: try await Resvg.find()).drawIconSet(icon, into: iconset)
            try await ToolStep.run(.name("iconutil"), ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("StateUI.icns").path])
        } else {
            keys["CFBundleIconFile"] = nil
        }
        let own = application.appendingPathComponent("Platforms/AppKit/Info.plist")
        try InfoPlist.compose(keys, over: files.fileExists(atPath: own.path) ? own : nil)
            .write(to: contents.appendingPathComponent("Info.plist"))

        if sign { try await ToolStep.run(.name("codesign"), ["--force", "--deep", "--sign", "-", bundle.path]) }
        return bundle
    }
}
#endif
