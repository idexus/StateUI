// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
@testable import StateUIAppKit
import XCTest

/// The artwork a program carries, found where `run()` is handed none.
final class AppKitCarriedArtworkTests: XCTestCase {
    /// A DEPLOYED COPY'S ARTWORK IS FOUND BESIDE IT: `.scripts/AppKit/deploy.sh` lays the application's
    /// `Resources` beside the program, and the host takes its `Images` and its icon from there.
    func testADeployedCopysArtworkIsFoundBesideIt() throws {
        let folder = try Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let resources = folder.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(
            at: resources.appendingPathComponent("Images"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: resources.appendingPathComponent("AppIcon"), withIntermediateDirectories: true)
        try Data().write(to: resources.appendingPathComponent("AppIcon/appicon_macos.svg"))

        let artwork = CarriedArtwork(program: folder.appendingPathComponent("NotesAppKit"), bundleResources: folder)

        XCTAssertEqual(artwork.images?.standardizedFileURL, resources.appendingPathComponent("Images").standardizedFileURL)
        XCTAssertEqual(
            artwork.icon?.standardizedFileURL,
            resources.appendingPathComponent("AppIcon/appicon_macos.svg").standardizedFileURL)
    }

    /// A BUNDLE'S OWN IMAGES COME FIRST, and it shows its own icon.
    func testABundlesOwnImagesComeFirst() throws {
        let folder = try Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let bundled = folder.appendingPathComponent("Notes.app/Contents/Resources")
        try FileManager.default.createDirectory(
            at: bundled.appendingPathComponent("Images"), withIntermediateDirectories: true)

        let artwork = CarriedArtwork(
            program: folder.appendingPathComponent("Notes.app/Contents/MacOS/Notes"), bundleResources: bundled)

        XCTAssertEqual(artwork.images?.standardizedFileURL, bundled.appendingPathComponent("Images").standardizedFileURL)
        XCTAssertNil(artwork.icon)
    }

    /// A program carrying nothing is handed nothing.
    func testAProgramCarryingNothingIsHandedNothing() throws {
        let folder = try Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }

        let artwork = CarriedArtwork(program: folder.appendingPathComponent("NotesAppKit"), bundleResources: folder)

        XCTAssertNil(artwork.images)
        XCTAssertNil(artwork.icon)
    }

    private static func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("artwork-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
#endif
