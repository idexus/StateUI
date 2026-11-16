// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit)
import Foundation
import StateUITooling
import XCTest

final class AppKitBundleTests: XCTestCase {
    private let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="blue"/></svg>"#

    /// An application laid out as StateUI's are, its product built: `Resources/Images`, its macOS icon, its own
    /// `Info.plist` keys - and the product and a library SwiftPM laid in a folder of binaries.
    private func application(ownKeys: Bool) throws -> (application: URL, binaries: URL, staging: URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bundle-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let files = FileManager.default
        let application = root.appendingPathComponent("Notes")
        for folder in ["Resources/Images", "Resources/AppIcon", "Platforms/AppKit"] {
            try files.createDirectory(at: application.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try svg.write(to: application.appendingPathComponent("Resources/Images/mark.svg"), atomically: true, encoding: .utf8)
        try svg.write(to: application.appendingPathComponent("Resources/AppIcon/appicon_macos.svg"), atomically: true, encoding: .utf8)
        if ownKeys {
            let own: [String: Any] = ["NSLocationUsageDescription": "Where notes were written."]
            try PropertyListSerialization.data(fromPropertyList: own, format: .xml, options: 0)
                .write(to: application.appendingPathComponent("Platforms/AppKit/Info.plist"))
        }
        let binaries = root.appendingPathComponent("bin")
        try files.createDirectory(at: binaries, withIntermediateDirectories: true)
        // A real program, as a signature asks of what it signs.
        try files.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: binaries.appendingPathComponent("NotesAppKit"))
        let staging = root.appendingPathComponent("staging")
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        return (application, binaries, staging)
    }

    /// The bundle holds the head and the libraries in `MacOS`, the pictures and the icon in `Resources`, and the
    /// host's `Info.plist` keys with the application's own laid over.
    func testTheBundleHoldsTheHeadItsLibrariesPicturesIconAndKeys() async throws {
        let (application, binaries, staging) = try application(ownKeys: true)
        try Data("library".utf8).write(to: binaries.appendingPathComponent("libStateUI.dylib"))
        let bundle = try await AppKitBundle(
            application: application, name: "Notes", product: "NotesAppKit", binaries: binaries,
            identity: ApplicationFile(identifier: "pl.example.notes", version: "2.1", build: 9, name: "My Notes"),
            minimumSystem: "26.4").assemble(in: staging, sign: false)

        let files = FileManager.default
        for path in ["Contents/MacOS/NotesAppKit", "Contents/MacOS/libStateUI.dylib", "Contents/Resources/Images/mark.svg",
                     "Contents/Resources/StateUI.icns", "Contents/Info.plist"] {
            XCTAssertTrue(files.fileExists(atPath: bundle.appendingPathComponent(path).path), path)
        }
        XCTAssertEqual(bundle.lastPathComponent, "NotesAppKit.app")
        let plist = try XCTUnwrap(try PropertyListSerialization.propertyList(
            from: Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any])
        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "pl.example.notes")
        XCTAssertEqual([plist["CFBundleShortVersionString"], plist["CFBundleVersion"]] as? [String], ["2.1", "9"])
        XCTAssertEqual(plist["CFBundleDisplayName"] as? String, "My Notes")
        XCTAssertEqual(plist["NSLocationUsageDescription"] as? String, "Where notes were written.")
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "StateUI")
        XCTAssertFalse(files.fileExists(atPath: staging.appendingPathComponent("StateUI.iconset").path))
    }

    /// The bundle is signed ad hoc, as a whole a Mac's verifier accepts.
    func testTheBundleIsSignedAdHoc() async throws {
        let (application, binaries, staging) = try application(ownKeys: false)
        let bundle = try await AppKitBundle(
            application: application, name: "Notes", product: "NotesAppKit", binaries: binaries,
            identity: ApplicationFile(identifier: "pl.example.notes", version: "2.1", build: 9, name: "My Notes"),
            minimumSystem: "26.4").assemble(in: staging)
        let said = Gathered()
        let verified = try await ProcessRunner().run(
            ProcessRequest(.name("codesign"), arguments: ["--verify", "--deep", "--verbose=1", bundle.path]), output: said.add)
        XCTAssertTrue(verified.succeeded, said.lines(of: .standardError).joined(separator: "\n"))
    }
}
#endif
