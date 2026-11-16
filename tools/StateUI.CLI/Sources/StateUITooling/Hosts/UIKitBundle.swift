// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import Foundation
import StateUIToolingProtocol

/// An application's UIKit bundle, assembled from what SwiftPM built for a simulator or a device: `<Product>.app` with
/// the head, the libraries in `Frameworks`, the application's pictures drawn three times over, the icon compiled from
/// its artwork, `Info.plist` from the host's keys and the application's own `Platforms/UIKit/Info.plist`, and a
/// signature - ad hoc for a simulator, a development profile's for a device.
/// Design: docs/design/tooling/apple-bundles.md#a-uikit-bundle
public struct UIKitBundle: Sendable {
    /// How the bundle is signed.
    public enum Signing: Sendable {
        /// Not at all: a test's bundle.
        case none
        /// Ad hoc, as a simulator runs it.
        case adHoc
        /// With a development profile and identity, as the device they provision runs it.
        case development(DevelopmentSigning)
    }

    /// The application's folder: its `Resources` and `Platforms/UIKit`.
    public var application: URL
    /// The application's name: `Gallery`.
    public var name: String
    /// The product SwiftPM built: `GalleryUIKit`.
    public var product: String
    /// The folder SwiftPM laid the product and the libraries in (`--show-bin-path`).
    public var binaries: URL
    /// What the application's `stateui.json` says: the bundle's identifier, version and build.
    public var identity: ApplicationFile
    /// The oldest iOS the bundle runs on.
    public var minimumSystem: String
    /// A simulator's or a device's.
    public var platform: AppleSDK.Platform
    /// A folder kept from one build to the next: the pictures drawn and the icon's catalog, drawn again only where
    /// their artwork changed.
    public var work: URL

    /// The bundle of `application`'s `product` as SwiftPM laid it in `binaries` for `platform`.
    public init(
        application: URL, name: String, product: String, binaries: URL, identity: ApplicationFile, minimumSystem: String,
        platform: AppleSDK.Platform, work: URL
    ) {
        self.application = application
        self.name = name
        self.product = product
        self.binaries = binaries
        self.identity = identity
        self.minimumSystem = minimumSystem
        self.platform = platform
        self.work = work
    }

    /// The bundle's folder's path within the artifact, and its program's.
    public var bundlePath: String { "\(product).app" }
    public var programPath: String { "\(product).app/\(product)" }

    /// The bundle's identifier, its `stateui.json`'s.
    public var identifier: String { identity.identifier }

    /// Assembles the bundle in `staging`, signed as `signing` says, and answers its folder.
    ///
    /// - Throws: ``ToolingError`` `TOOL_FAILED` where `actool` or `codesign` refused.
    public func assemble(in staging: URL, signing: Signing) async throws -> URL {
        let files = FileManager.default
        let bundle = staging.appendingPathComponent(bundlePath)
        let frameworks = bundle.appendingPathComponent("Frameworks")
        try files.createDirectory(at: frameworks, withIntermediateDirectories: true)
        try files.createDirectory(at: work, withIntermediateDirectories: true)

        let program = bundle.appendingPathComponent(product)
        try files.copyItem(at: binaries.appendingPathComponent(product), to: program)
        let libraries = try files.contentsOfDirectory(atPath: binaries.path).filter { $0.hasSuffix(".dylib") }.sorted()
        for library in libraries {
            try files.copyItem(at: binaries.appendingPathComponent(library), to: frameworks.appendingPathComponent(library))
        }
        // SwiftPM's rpaths point into its own folders; the bundle's libraries stand in Frameworks.
        try? await ToolStep.run(.name("install_name_tool"), ["-add_rpath", "@executable_path/Frameworks", program.path])

        let images = application.appendingPathComponent("Resources/Images")
        if files.fileExists(atPath: images.path) {
            let drawn = work.appendingPathComponent("Images")
            try await Pictures(renderer: try await Resvg.find()).draw(images, into: drawn)
            try files.copyItem(at: drawn, to: bundle.appendingPathComponent("Images"))
        }

        var keys = InfoPlist.iOS(name: name, product: product, identity: identity, minimumSystem: minimumSystem, platform: platform)
        let artwork = application.appendingPathComponent("Resources/AppIcon")
        let (background, mark) = (artwork.appendingPathComponent("appicon_bkg.svg"), artwork.appendingPathComponent("appicon_mark.svg"))
        if files.fileExists(atPath: background.path), files.fileExists(atPath: mark.path) {
            keys.merge(try await compileIcon(background: background, mark: mark, into: bundle)) { _, icon in icon }
        }
        let own = application.appendingPathComponent("Platforms/UIKit/Info.plist")
        try InfoPlist.compose(keys, over: files.fileExists(atPath: own.path) ? own : nil)
            .write(to: bundle.appendingPathComponent("Info.plist"))

        let signed = libraries.map { frameworks.appendingPathComponent($0).path }
        switch signing {
        case .none:
            break
        case .adHoc:
            if !signed.isEmpty { try await ToolStep.run(.name("codesign"), ["--force", "--sign", "-"] + signed) }
            try await ToolStep.run(.name("codesign"), ["--force", "--sign", "-", bundle.path])
        case .development(let development):
            try files.copyItem(at: development.profile.file, to: bundle.appendingPathComponent("embedded.mobileprovision"))
            let entitlements = work.appendingPathComponent("entitlements.plist")
            try development.profile.entitlements(for: identifier).write(to: entitlements)
            let sign = ["--force", "--sign", development.identity, "--timestamp=none"]
            if !signed.isEmpty { try await ToolStep.run(.name("codesign"), sign + signed) }
            try await ToolStep.run(.name("codesign"), sign + ["--entitlements", entitlements.path, bundle.path])
        }
        return bundle
    }

    /// The icon drawn into the work folder's catalog and compiled by `actool` into `bundle`; answers the keys
    /// `actool` says the bundle's `Info.plist` takes.
    private func compileIcon(background: URL, mark: URL, into bundle: URL) async throws -> [String: Any] {
        let catalog = work.appendingPathComponent("Assets.xcassets")
        let keys = work.appendingPathComponent("icon.plist")
        try await Pictures(renderer: try await Resvg.find()).drawAppIcon(background: background, mark: mark, into: catalog)
        try await ToolStep.run(.name("xcrun"), [
            "actool", catalog.path, "--compile", bundle.path, "--platform", platform.rawValue,
            "--minimum-deployment-target", minimumSystem, "--target-device", "iphone", "--target-device", "ipad",
            "--app-icon", "AppIcon", "--output-partial-info-plist", keys.path, "--output-format", "human-readable-text",
        ])
        let read = try PropertyListSerialization.propertyList(from: Data(contentsOf: keys), format: nil)
        return read as? [String: Any] ?? [:]
    }
}
#endif
