// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The applications under apps/, their artwork, and the scaffolder that makes
// one.
//
// An application lives under apps/<Name>/ and states every connection to the
// repository as a relative path - to the library's Swift packages and to the
// hosts'. A path that no longer resolves fails late: SwiftPM cannot resolve,
// with a message about the symptom rather than the move that caused it. These
// tests read the paths out of the manifests and resolve them here, so a moved
// directory names the file that still points at the old place.
//
// The scaffolder - .scripts/new-app.sh, .scripts/new-app.ps1, and the StateUI
// extension's "New Application in apps/" that runs them - makes an application by copying
// apps/HelloWorld under another name. The bash half runs here for real, into a
// temporary directory, and what it made is read back; the PowerShell half
// cannot run where these tests run, so it is held to agreement with the bash
// half.

import Foundation
import XCTest

final class AppsTests: XCTestCase {
    /// `apps/HelloWorld`, what a new application is made from.
    private var helloWorld: URL {
        Fixtures.repository.appendingPathComponent("apps/HelloWorld")
    }

    // MARK: - The layout

    /// Every application under `apps/` is wired to the repository: its Swift
    /// manifest declares the application's module, `<Name>UI`, every package
    /// and target path the manifest names resolves, and the one export a host
    /// calls by name is declared under `Sources/`.
    ///
    /// A new application is checked the moment it exists, with nothing to
    /// remember.
    func testEveryAppUnderAppsIsWiredToTheRepo() throws {
        let applications = try Fixtures.applications()
        XCTAssertFalse(
            applications.isEmpty, "apps/ holds no application - the Gallery and HelloWorld live there.")

        for app in applications {
            let name = app.lastPathComponent

            // Finder reads a directory named Something.App as a bundle.
            XCTAssertFalse(name.contains("."), "\(name): an application's name holds no dot.")

            let manifestFile = app.appendingPathComponent("Package.swift")

            guard FileManager.default.fileExists(atPath: manifestFile.path) else {
                XCTFail("\(name): no Package.swift - SourceKit and every head read one.")
                continue
            }

            let manifest = try String(contentsOf: manifestFile, encoding: .utf8)

            // The TARGET, not merely the name somewhere in the file: a manifest
            // whose package and product were renamed and whose target was not
            // is refused by SwiftPM.
            XCTAssertTrue(
                squeezed(manifest).contains(".target(name:\"\(name)UI\""),
                "\(name): Package.swift declares no target called \(name)UI - SwiftPM refuses "
                    + "the package.")

            for (path, isPackage) in manifestPaths(in: manifest) {
                let directory = app.appendingPathComponent(path).standardizedFileURL
                let wanted = isPackage ? directory.appendingPathComponent("Package.swift") : directory

                XCTAssertTrue(
                    FileManager.default.fileExists(atPath: wanted.path),
                    "\(name): Package.swift names \(path), and \(wanted.path) does not exist.")
            }

            // Nothing in the module runs until the host calls this export by
            // name, and the manifest compiles Sources/ whole, so the file
            // declaring it may sit anywhere under it.
            let sources = app.appendingPathComponent("Sources")
            let registers = try Fixtures.files(under: sources)
                .filter { $0.hasSuffix(".swift") }
                .contains { relative in
                    try String(contentsOf: sources.appendingPathComponent(relative), encoding: .utf8)
                        .contains("@_cdecl(\"stateui_app_register\")")
                }

            XCTAssertTrue(
                registers,
                "\(name): nothing under Sources/ declares stateui_app_register - the Android head "
                    + "can never start the application.")
        }
    }

    // MARK: - The artwork

    /// Every SVG an application holds opens with its element. Linux ships the
    /// vectors under the names the other platforms rasterize to, and GTK
    /// decides what a file is by sniffing its first hundred or so bytes: a
    /// comment before `<svg` pushes the element out of that window, and the
    /// picture silently does not appear. A comment goes inside the element.
    func testEverySvgSaysWhatItIsInsideTheSniffWindow() throws {
        let window = 100

        for application in try Fixtures.applications() {
            let name = application.lastPathComponent
            let vectors = Fixtures.files(
                under: application, leavingOut: Fixtures.byproducts.union([".scripts"]))
                .filter { $0.hasSuffix(".svg") }

            XCTAssertFalse(
                vectors.isEmpty, "\(name) holds no SVG - an application without artwork has no icon.")

            for relative in vectors {
                let text = try String(
                    contentsOf: application.appendingPathComponent(relative), encoding: .utf8)

                guard let opening = text.range(of: "<svg") else {
                    XCTFail("\(name)/\(relative) has no <svg element at all.")
                    continue
                }

                let at = text.utf8.distance(from: text.utf8.startIndex, to: opening.lowerBound)
                XCTAssertLessThan(
                    at, window,
                    "\(name)/\(relative) opens its <svg element at byte \(at), past the "
                        + "~\(window) bytes GTK sniffs - the picture does not load on Linux. A "
                        + "comment goes inside the element.")
            }
        }
    }

    /// An application's artwork is one flat namespace, so no two files under
    /// its `Resources/` share a base name. The folders are the author's
    /// convenience: a platform gets `stateui_mark.png` from Images and
    /// `stateui_mark` from the icon side by side in one bundle, and Apple's
    /// build refuses the pair out loud while the vectors Linux copies under a
    /// rasterized name silently overwrite one another.
    ///
    /// The base name, not the whole file name: `mark.svg` and `mark.png` are
    /// one picture to everything downstream, an SVG being asked for as a PNG.
    func testNoTwoResourcesInOneAppShareAName() throws {
        for application in try Fixtures.applications() {
            let name = application.lastPathComponent
            let pictures = Fixtures.files(under: application.appendingPathComponent("Resources"))
                .filter { $0.hasSuffix(".svg") || $0.hasSuffix(".png") }

            XCTAssertFalse(pictures.isEmpty, "\(name) has no artwork under Resources/.")

            var seen: [String: String] = [:]

            for path in pictures {
                let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

                if let first = seen[stem] {
                    XCTFail("\(name): Resources/\(first) and Resources/\(path) are two files under "
                        + "one name - a platform sees them flat.")
                }

                seen[stem] = path
            }
        }
    }

    // MARK: - The scaffolder

    /// A new application is HelloWorld under another name. new-app.sh copies
    /// HelloWorld's tree, leaves every byproduct of its builds behind, and
    /// renames it in file names and inside every file, the application
    /// identifier in lower case - checked file for file against HelloWorld
    /// itself, so a file HelloWorld gains is asked about the day it appears,
    /// and a file the rename does not reach is named here rather than in an
    /// application that builds under one name and runs under another.
    ///
    func testANewAppIsHelloWorldUnderAnotherName() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let made = try newApp("Probe", into: root)
        XCTAssertEqual(made.status, 0, "new-app.sh failed:\n\(made.output)")

        let app = root.appendingPathComponent("Probe")
        let model = Fixtures.files(under: helloWorld)
        XCTAssertFalse(model.isEmpty, "apps/HelloWorld holds nothing to make an application from.")

        // The same files under the new name, and nothing besides: no build
        // output, no Finder settings, nothing of HelloWorld's left out.
        XCTAssertEqual(
            Fixtures.files(under: app, leavingOut: []),
            model.map { $0.replacingOccurrences(of: "HelloWorld", with: "Probe") }.sorted(),
            "the new application's files are not HelloWorld's under the new name.")

        for original in model {
            let relative = original.replacingOccurrences(of: "HelloWorld", with: "Probe")

            // A file that is not there is named by the comparison above.
            guard let written = FileManager.default.contents(
                atPath: app.appendingPathComponent(relative).path)
            else { continue }

            let source = try Data(contentsOf: helloWorld.appendingPathComponent(original))
            assertSameFile(
                written, Fixtures.helloWorld(source, renamedTo: "Probe"),
                "\(relative) is not HelloWorld's \(original) with the name changed.")
        }

        // No file, and no file's text, still names the model - in any spelling.
        for relative in Fixtures.files(under: app, leavingOut: []) {
            XCTAssertFalse(
                relative.lowercased().contains("helloworld"),
                "\(relative) is still named after HelloWorld.")

            guard let text = try? String(
                contentsOf: app.appendingPathComponent(relative), encoding: .utf8)
            else { continue }

            XCTAssertFalse(
                text.lowercased().contains("helloworld"),
                "\(relative) still says HelloWorld - the rename missed it.")
        }

        let gradle = try String(
            contentsOf: app.appendingPathComponent("Platforms/Android/build.gradle.kts"), encoding: .utf8)
        XCTAssertTrue(
            gradle.contains("applicationId = \"com.stateui.probe\""),
            "the application identifier is not the new name in lower case.")

        let application = try String(
            contentsOf: app.appendingPathComponent("Sources/ProbeApp.swift"), encoding: .utf8)
        XCTAssertTrue(
            application.contains("stateUIUseApp(ProbeApp())"),
            "the new module does not register its own application.")
    }

    /// The names new-app.sh refuses, each for the reason it cannot build: no
    /// name at all; a dot, which Finder reads as a bundle; a leading digit, a
    /// hyphen or a space, which no Swift module holds; and
    /// StateUI, which is the library. A refused name leaves nothing behind, and
    /// an existing directory is refused rather than written into.
    func testTheScaffolderRefusesANameItCannotBuild() throws {
        for bad in ["", "My.App", "1Fish", "My-App", "has space", "StateUI"] {
            let root = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }

            let made = try newApp(bad, into: root)
            XCTAssertNotEqual(made.status, 0, "'\(bad)' should have been refused: \(made.output)")
            XCTAssertEqual(
                Fixtures.files(under: root, leavingOut: []), [],
                "'\(bad)' was refused and still left files behind.")
        }

        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let taken = root.appendingPathComponent("Taken")
        try FileManager.default.createDirectory(at: taken, withIntermediateDirectories: true)
        try "still here".write(
            to: taken.appendingPathComponent("keep.txt"), atomically: true, encoding: .utf8)

        let made = try newApp("Taken", into: root)
        XCTAssertNotEqual(made.status, 0, "an existing directory should be refused.")
        XCTAssertEqual(
            Fixtures.files(under: taken, leavingOut: []), ["keep.txt"],
            "the existing directory was written into.")
        XCTAssertEqual(
            try String(contentsOf: taken.appendingPathComponent("keep.txt"), encoding: .utf8),
            "still here")
    }

    /// The PowerShell half cannot run where these tests run, so it is held to
    /// agreement with the bash half: both copy the same parts of HelloWorld,
    /// rename inside the same kinds of file and refuse by the same rule - the
    /// pieces that drift first when one script is edited without the other.
    func testTheWindowsScaffolderKeepsStep() throws {
        let sh = try script("new-app.sh")
        let ps = try script("new-app.ps1")

        let shCopied = (sh.occurrences(between: "for item in ", and: "; do").first ?? "")
            .split(separator: " ").map(String.init)
        let psCopied = quoted(ps.occurrences(between: "foreach ($item in @(", and: "))").first ?? "")
        XCTAssertFalse(shCopied.isEmpty, "new-app.sh names nothing to copy.")
        XCTAssertEqual(
            Set(psCopied), Set(shCopied), "the two scaffolders copy different parts of HelloWorld.")

        let shRenamed = sh.occurrences(between: "-name \"*", and: "\"")
        let psRenamed = quoted(ps.occurrences(between: "$extensions = @(", and: ")").first ?? "")
        XCTAssertFalse(shRenamed.isEmpty, "new-app.sh renames inside no file.")
        XCTAssertEqual(
            Set(psRenamed), Set(shRenamed),
            "the two scaffolders rename inside different kinds of file.")

        for piece in ["^[A-Za-z][A-Za-z0-9]*$", "\"StateUI\"", "apps/HelloWorld", "helloworld", ".DS_Store"] {
            XCTAssertTrue(sh.contains(piece), "new-app.sh no longer says \(piece)")
            XCTAssertTrue(ps.contains(piece), "new-app.ps1 no longer says \(piece)")
        }
    }

    // MARK: - Helpers

    /// Every path a manifest names, and whether it names a package - a
    /// directory holding a Package.swift - rather than a target's own files.
    /// Comment lines are left out.
    private func manifestPaths(in manifest: String) -> [(path: String, isPackage: Bool)] {
        manifest.split(separator: "\n")
            .filter { !$0.drop(while: { $0 == " " }).hasPrefix("//") }
            .flatMap { line -> [(path: String, isPackage: Bool)] in
                let isPackage = line.contains(".package(")
                return String(line).occurrences(between: "path: \"", and: "\"")
                    .map { (path: $0, isPackage: isPackage) }
            }
    }

    /// A text with every space and line break taken out, so a call wrapped
    /// over several lines reads as the one call it is.
    private func squeezed(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    /// The strings between double quotes, in order.
    private func quoted(_ text: String) -> [String] {
        text.occurrences(between: "\"", and: "\"")
    }

    /// One of the scaffolders, read as text.
    private func script(_ name: String) throws -> String {
        try String(
            contentsOf: Fixtures.repository.appendingPathComponent(".scripts/\(name)"),
            encoding: .utf8)
    }

    /// A fresh, empty directory of the test's own.
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-newapp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Runs the repository's new-app.sh for a name, into a destination.
    private func newApp(
        _ name: String, into destination: URL
    ) throws -> (status: Int32, output: String) {
        try run(
            Fixtures.repository.appendingPathComponent(".scripts/new-app.sh"),
            [name, destination.path])
    }

    /// Runs a bash script and collects what it said, standard error included.
    /// Skipped where there is no bash: Windows has new-app.ps1, held to
    /// agreement with new-app.sh by `testTheWindowsScaffolderKeepsStep`.
    private func run(
        _ script: URL, _ arguments: [String]
    ) throws -> (status: Int32, output: String) {
        let bash = URL(fileURLWithPath: "/bin/bash")

        guard FileManager.default.fileExists(atPath: bash.path) else {
            throw XCTSkip("no /bin/bash here; new-app.ps1 is held to agreement with new-app.sh.")
        }

        let process = Process()
        process.executableURL = bash
        process.arguments = [script.path] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (process.terminationStatus, String(decoding: output, as: UTF8.self))
    }
}
