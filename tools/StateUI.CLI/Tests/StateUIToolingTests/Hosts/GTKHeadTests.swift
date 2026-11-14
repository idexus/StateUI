// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class GTKHeadTests: XCTestCase {
    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("gtk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// An application laid out as StateUI's are: its GTK head naming its ID, its pictures, its icon and link schemes.
    private func application(in root: URL) throws -> URL {
        let application = root.appendingPathComponent("Notes")
        for folder in ["Platforms/GTK", "Resources/Images", "Resources/AppIcon"] {
            try FileManager.default.createDirectory(at: application.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        try "GTKHost.run(applicationID: \"com.stateui.notes\")\n".write(
            to: application.appendingPathComponent("Platforms/GTK/main.swift"), atomically: true, encoding: .utf8)
        try "notes\n\nstateui-notes\n".write(to: application.appendingPathComponent("Platforms/GTK/link-schemes"), atomically: true, encoding: .utf8)
        try "<svg/>".write(to: application.appendingPathComponent("Resources/Images/mark.svg"), atomically: true, encoding: .utf8)
        try "<svg/>".write(to: application.appendingPathComponent("Resources/AppIcon/appicon_gnome.svg"), atomically: true, encoding: .utf8)
        return application
    }

    /// The head is the program, every library beside it and the pictures as they are; it is known by the ID its head
    /// runs as.
    func testTheHeadIsItsProgramLibrariesAndPictures() throws {
        let root = try folder()
        let application = try application(in: root)
        let binaries = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: binaries, withIntermediateDirectories: true)
        for file in ["NotesGTK", "libStateUI.so", "libStateUIGTK.so", "NotesGTK.swiftmodule"] {
            try Data().write(to: binaries.appendingPathComponent(file))
        }
        let staging = root.appendingPathComponent("staging")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)

        try GTKHead(application: application, product: "NotesGTK", binaries: binaries).assemble(in: staging)

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path).sorted(),
                       ["Images", "NotesGTK", "libStateUI.so", "libStateUIGTK.so"])
        XCTAssertEqual(GTKHead.applicationID(of: application), "com.stateui.notes")
        XCTAssertNil(GTKHead.applicationID(of: root))
    }

    /// The desktop entry starts the program with the links it opens, shows the icon by the ID and matches the
    /// window by the product; its schemes are the head's list, one a line.
    func testTheDesktopEntryStartsTheProgramByItsID() throws {
        let application = try application(in: try folder())
        XCTAssertEqual(GTKDesktop.schemes(of: application), ["notes", "stateui-notes"])
        let entry = GTKDesktop.entry(
            name: "Notes", program: URL(fileURLWithPath: "/a/NotesGTK"), product: "NotesGTK", identifier: "com.stateui.notes",
            schemes: ["notes"])
        XCTAssertEqual(entry, """
            [Desktop Entry]
            Type=Application
            Name=Notes
            Exec=/a/NotesGTK %u
            Icon=com.stateui.notes
            StartupWMClass=NotesGTK
            Terminal=false
            Categories=Development;
            MimeType=x-scheme-handler/notes;

            """)
        XCTAssertFalse(GTKDesktop.entry(name: "N", program: URL(fileURLWithPath: "/a"), product: "P", identifier: "i", schemes: []).contains("MimeType"))
    }

    /// Installing a GTK artifact writes its entry and icon where the user's data folder says; an artifact of another
    /// host, or a folder no build published, is refused.
    func testInstallingWritesTheEntryWhereTheUsersDataIs() async throws {
        let root = try folder()
        let application = try application(in: root)
        let artifact = root.appendingPathComponent("artifact")
        try FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        let manifest = { (host: HostFamily) in
            ArtifactManifest(
                id: "gtk-x-debug", producerOperationId: "op", createdAt: "now", applicationUri: FileURI.string(application),
                host: host, configuration: .debug, architecture: .arm64, productName: "NotesGTK", entryPoints: ["NotesGTK"],
                signing: .none, applicationName: "Notes", identifier: "com.stateui.notes")
        }
        try JSONEncoder().encode(manifest(.gtk)).write(to: artifact.appendingPathComponent("artifact.json"))
        let data = root.appendingPathComponent("data")

        let installed = try await ApplicationInstaller(environment: ["XDG_DATA_HOME": data.path], home: root).install(artifact)

        let entry = data.appendingPathComponent("applications/com.stateui.notes.desktop")
        XCTAssertEqual(installed.writtenUris.count, 2)
        XCTAssertTrue(try String(contentsOf: entry, encoding: .utf8).contains("Exec=\(artifact.appendingPathComponent("NotesGTK").path) %u"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: data.appendingPathComponent("icons/hicolor/scalable/apps/com.stateui.notes.svg").path))

        try JSONEncoder().encode(manifest(.appkit)).write(to: artifact.appendingPathComponent("artifact.json"))
        for (folder, code) in [(artifact, ToolingErrorCode.invalidConfiguration), (root, .notFound)] {
            do {
                _ = try await ApplicationInstaller(environment: ["XDG_DATA_HOME": data.path], home: root).install(folder)
                XCTFail("\(folder.lastPathComponent) was installed")
            } catch let error as ToolingError {
                XCTAssertEqual(error.code, code)
            }
        }
    }
}
