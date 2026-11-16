// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import Foundation
import StateUITooling
import XCTest

final class UIKitBundleTests: XCTestCase {
    private let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="blue"/></svg>"#

    /// An application laid out as StateUI's are, its UIKit product built: `Resources/Images`, the icon's two layers,
    /// its own `Info.plist` keys - and the product SwiftPM laid in a folder of binaries.
    private func bundle(platform: AppleSDK.Platform = .iOSSimulator) throws -> UIKitBundle {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent("uikit-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let application = root.appendingPathComponent("Notes")
        for folder in ["Resources/Images", "Resources/AppIcon", "Platforms/UIKit"] {
            try files.createDirectory(at: application.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        for picture in ["Images/mark.svg", "AppIcon/appicon_bkg.svg", "AppIcon/appicon_mark.svg"] {
            try svg.write(to: application.appendingPathComponent("Resources/\(picture)"), atomically: true, encoding: .utf8)
        }
        let own: [String: Any] = ["CFBundleDisplayName": "My Notes", "NSLocationWhenInUseUsageDescription": "Where notes were written."]
        try PropertyListSerialization.data(fromPropertyList: own, format: .xml, options: 0)
            .write(to: application.appendingPathComponent("Platforms/UIKit/Info.plist"))
        let binaries = root.appendingPathComponent("bin")
        try files.createDirectory(at: binaries, withIntermediateDirectories: true)
        // A real program, as a signature asks of what it signs.
        try files.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: binaries.appendingPathComponent("NotesUIKit"))
        try files.createDirectory(at: root.appendingPathComponent("staging"), withIntermediateDirectories: true)
        return UIKitBundle(
            application: application, name: "Notes", product: "NotesUIKit", binaries: binaries,
            identity: ApplicationFile(identifier: "pl.example.notes", version: "2.1", build: 9),
            minimumSystem: "26.4", platform: platform, work: root.appendingPathComponent("work"))
    }

    /// The bundle holds the head, its libraries in `Frameworks`, the pictures drawn three times over, the icon
    /// `actool` compiled, and the host's keys with the icon's and the application's own laid over.
    func testTheBundleHoldsTheHeadItsLibrariesPicturesIconAndKeys() async throws {
        let bundle = try bundle()
        try Data("library".utf8).write(to: bundle.binaries.appendingPathComponent("libStateUI.dylib"))
        let staging = bundle.work.deletingLastPathComponent().appendingPathComponent("staging")
        let folder = try await bundle.assemble(in: staging, signing: .none)

        XCTAssertEqual(folder.lastPathComponent, "NotesUIKit.app")
        let files = FileManager.default
        for path in ["NotesUIKit", "Frameworks/libStateUI.dylib", "Images/mark@3x.png", "Assets.car", "Info.plist"] {
            XCTAssertTrue(files.fileExists(atPath: folder.appendingPathComponent(path).path), path)
        }
        XCTAssertTrue(try files.contentsOfDirectory(atPath: folder.path).contains { $0.hasPrefix("AppIcon60x60") })
        let plist = try XCTUnwrap(try PropertyListSerialization.propertyList(
            from: Data(contentsOf: folder.appendingPathComponent("Info.plist")), format: nil) as? [String: Any])
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "pl.example.notes")
        XCTAssertEqual([plist["CFBundleShortVersionString"], plist["CFBundleVersion"]] as? [String], ["2.1", "9"])
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "My Notes")
        XCTAssertEqual(plist["NSLocationWhenInUseUsageDescription"] as? String, "Where notes were written.")
        XCTAssertEqual(plist["CFBundleSupportedPlatforms"] as? [String], ["iPhoneSimulator"])
        XCTAssertNotNil(plist["CFBundleIcons"])
        XCTAssertNotNil(plist["CFBundleIcons~ipad"])
        XCTAssertEqual(try files.contentsOfDirectory(atPath: staging.path), ["NotesUIKit.app"])
    }

    /// A simulator's bundle is signed ad hoc, as a whole the verifier accepts.
    func testASimulatorsBundleIsSignedAdHoc() async throws {
        let bundle = try bundle()
        let staging = bundle.work.deletingLastPathComponent().appendingPathComponent("staging")
        let folder = try await bundle.assemble(in: staging, signing: .adHoc)
        let said = Gathered()
        let verified = try await ProcessRunner().run(
            ProcessRequest(.name("codesign"), arguments: ["--verify", "--verbose=1", folder.path]), output: said.add)
        XCTAssertTrue(verified.succeeded, said.lines(of: .standardError).joined(separator: "\n"))
        let shown = Gathered()
        _ = try await ProcessRunner().run(
            ProcessRequest(.name("codesign"), arguments: ["-dv", folder.path]), output: shown.add)
        XCTAssertTrue(shown.lines(of: .standardError).contains { $0.contains("adhoc") }, shown.lines(of: .standardError).joined(separator: "\n"))
    }
}
#endif
