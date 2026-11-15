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

    /// Under gdb a GTK critical's domain and expression are read from the architecture's argument registers, the
    /// run going on past it, and a crash's stack is said whole.
    func testGdbTrapsEveryCriticalOnTheArchitecturesRegisters() {
        let arm = GTKHead.gdbCommands(for: .arm64)
        XCTAssertTrue(arm.contains("break g_return_if_fail_warning"))
        XCTAssertTrue(arm.contains("(char *)$x1, (char *)$x2"))
        XCTAssertTrue(arm.contains("continue\nend\nrun\n"))
        XCTAssertTrue(GTKHead.gdbCommands(for: .x86_64).contains("(char *)$rsi, (char *)$rdx"))
    }

    /// Under gdb a program that ends by itself ends the run with its own status and says no stop; one a signal
    /// stops says its stack and ends the run as that signal would.
    func testGdbEndsTheRunAsTheProgramEnds() async throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/gdb") else { throw XCTSkip("No gdb on this machine.") }
        let commands = FileManager.default.temporaryDirectory.appendingPathComponent("gdb-\(UUID().uuidString).cmd")
        defer { try? FileManager.default.removeItem(at: commands) }
        #if arch(x86_64)
        try Data(GTKHead.gdbCommands(for: .x86_64).utf8).write(to: commands)
        #else
        try Data(GTKHead.gdbCommands(for: .arm64).utf8).write(to: commands)
        #endif
        for (script, status, stops) in [("exit 3", Int32(3), false), ("exit 0", 0, false), ("kill -SEGV $$", 139, true)] {
            let said = Gathered()
            let outcome = try await ProcessRunner().run(
                ProcessRequest(.path("/usr/bin/gdb"), arguments: ["-batch", "-x", commands.path, "--args", "/bin/sh", "-c", script]),
                output: said.add)
            let words = said.lines(of: .standardOutput) + said.lines(of: .standardError)
            XCTAssertEqual(outcome.exitStatus, status, "\(script): \(words.suffix(4))")
            XCTAssertEqual(words.contains("=== STOPPED"), stops, script)
        }
    }
}
