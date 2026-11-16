// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ApplicationMakerTests: XCTestCase {
    private let helloWorld = ProjectReaderTests.repository.appendingPathComponent("apps/HelloWorld")

    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// The files under `root`, every entry named with a dot left out - as the maker leaves them - by their paths
    /// from it.
    private func files(under root: URL, at path: String = "") -> [String] {
        let folder = path.isEmpty ? root : root.appendingPathComponent(path)
        let entries = ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
        return entries.filter { !$0.hasPrefix(".") }.flatMap { entry -> [String] in
            let relative = path.isEmpty ? entry : path + "/" + entry
            var isFolder: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path, isDirectory: &isFolder)
            return exists && isFolder.boolValue ? files(under: root, at: relative) : [relative]
        }.sorted()
    }

    /// A new application is HelloWorld under another name: the same files, no build's leftovers, the name changed in
    /// every file's name and text, the application identifier in lower case - its own `stateui.json` at 1.0.0, build
    /// 1 - and its checkout named by the path from it.
    func testANewApplicationIsHelloWorldUnderAnotherName() throws {
        let parent = try folder()
        let made = try ApplicationMaker().make("Probe", in: parent, from: ProjectReaderTests.repository)

        let model = files(under: helloWorld)
        XCTAssertFalse(model.isEmpty)
        XCTAssertEqual(files(under: made), model.map { $0.replacingOccurrences(of: "HelloWorld", with: "Probe") }.sorted())
        for original in model where !["Package.swift", "stateui.json"].contains(original) {
            let source = try Data(contentsOf: helloWorld.appendingPathComponent(original))
            let expected = String(data: source, encoding: .utf8).map {
                Data($0.replacingOccurrences(of: "HelloWorld", with: "Probe").replacingOccurrences(of: "helloworld", with: "probe").utf8)
            } ?? source
            let written = try Data(contentsOf: made.appendingPathComponent(original.replacingOccurrences(of: "HelloWorld", with: "Probe")))
            XCTAssertEqual(written, expected, "\(original) is not HelloWorld's with the name changed")
        }
        for relative in files(under: made) {
            XCTAssertFalse(relative.lowercased().contains("helloworld"), relative)
            let text = (try? String(contentsOf: made.appendingPathComponent(relative), encoding: .utf8)) ?? ""
            XCTAssertFalse(text.lowercased().contains("helloworld"), "\(relative) still says HelloWorld")
        }
        XCTAssertEqual(
            try ApplicationFile.read(made.appendingPathComponent("stateui.json")),
            ApplicationFile(identifier: "com.example.probe", version: "1.0.0", build: 1))
        let gradle = try String(contentsOf: made.appendingPathComponent("Platforms/Android/build.gradle.kts"), encoding: .utf8)
        XCTAssertTrue(gradle.contains("applicationId = \"com.stateui.probe\""))
        let head = try String(contentsOf: made.appendingPathComponent("Platforms/AppKit/main.swift"), encoding: .utf8)
        XCTAssertTrue(head.contains("ProbeApp.register()"))

        let checkout = ApplicationMaker.relativePath(from: made, to: ProjectReaderTests.repository)
        let manifest = try String(contentsOf: made.appendingPathComponent("Package.swift"), encoding: .utf8)
        XCTAssertTrue(manifest.contains(".package(name: \"StateUIRoot\", path: \"\(checkout)\")"), manifest)
        XCTAssertFalse(manifest.contains("\"../..\""))
    }

    /// An application named by an identifier is made with it in its `stateui.json`; one some platform refuses makes
    /// nothing.
    func testANewApplicationTakesTheIdentifierGiven() throws {
        let parent = try folder()
        let made = try ApplicationMaker().make("Probe", identifier: "pl.example.probe", in: parent, from: ProjectReaderTests.repository)
        XCTAssertEqual(try ApplicationFile.read(made.appendingPathComponent("stateui.json")).identifier, "pl.example.probe")

        XCTAssertThrowsError(
            try ApplicationMaker().make("Other", identifier: "pl.my-company.other", in: parent, from: ProjectReaderTests.repository)
        ) {
            XCTAssertEqual(($0 as? ToolingError)?.code, .invalidName)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: parent.appendingPathComponent("Other").path))
    }

    /// An application made in a checkout's own `apps/` names the checkout `../..`, as HelloWorld does.
    func testAnApplicationInTheCheckoutsAppsNamesItAsHelloWorldDoes() throws {
        let checkout = ProjectReaderTests.repository
        XCTAssertEqual(ApplicationMaker.relativePath(from: checkout.appendingPathComponent("apps/Notes"), to: checkout), "../..")
        XCTAssertEqual(
            ApplicationMaker.relativePath(from: URL(fileURLWithPath: "/w/group/apps/Notes"), to: URL(fileURLWithPath: "/w/group/StateUI")),
            "../../StateUI")
    }

    /// A name no Swift module, process or folder takes - and the library's own - is refused, leaving nothing behind.
    func testANameThatCannotBuildIsRefused() throws {
        for bad in ["", "My.App", "1Fish", "My-App", "has space", "StateUI"] {
            let parent = try folder()
            XCTAssertThrowsError(try ApplicationMaker().make(bad, in: parent, from: ProjectReaderTests.repository), bad) {
                XCTAssertEqual(($0 as? ToolingError)?.code, .invalidName, bad)
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: parent.path), [], "\(bad) left files behind")
        }
    }

    /// A folder already holding files is refused and left as it was; an empty one is made into the application.
    func testAFolderHoldingFilesIsRefusedAndLeftAsItWas() throws {
        let parent = try folder()
        let taken = parent.appendingPathComponent("Taken")
        try FileManager.default.createDirectory(at: taken, withIntermediateDirectories: true)
        try "still here".write(to: taken.appendingPathComponent("keep.txt"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ApplicationMaker().make("Taken", in: parent, from: ProjectReaderTests.repository)) {
            XCTAssertEqual(($0 as? ToolingError)?.code, .alreadyExists)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: taken.path), ["keep.txt"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: parent.path), ["Taken"])

        try FileManager.default.createDirectory(at: parent.appendingPathComponent("Empty"), withIntermediateDirectories: true)
        let made = try ApplicationMaker().make("Empty", in: parent, from: ProjectReaderTests.repository)
        XCTAssertTrue(FileManager.default.fileExists(atPath: made.appendingPathComponent("Package.swift").path))
    }

    /// A folder that is no checkout gives nothing to make an application from.
    func testNoCheckoutGivesNothingToMakeFrom() throws {
        let parent = try folder()
        XCTAssertThrowsError(try ApplicationMaker().make("Notes", in: parent, from: parent)) {
            XCTAssertEqual(($0 as? ToolingError)?.code, .projectNotFound)
        }
    }

    /// On Windows a folder on another drive has no path from here but its own - the drive and its folders - and one
    /// on the same drive is reached by the path between them.
    func testAFolderOnAnotherDriveIsNamedByItsWholePath() throws {
        #if os(Windows)
        let notes = URL(fileURLWithPath: #"C:\work\Notes"#)
        XCTAssertEqual(ApplicationMaker.relativePath(from: notes, to: URL(fileURLWithPath: #"D:\a\StateUI"#)), "D:/a/StateUI")
        XCTAssertEqual(ApplicationMaker.relativePath(from: notes, to: URL(fileURLWithPath: #"C:\a\StateUI"#)), "../../a/StateUI")
        #else
        throw XCTSkip("a drive is Windows'")
        #endif
    }

    /// A made application is a project of its own, reading the checkout it was made from.
    func testAMadeApplicationReadsAsAProject() async throws {
        let parent = try folder()
        let made = try ApplicationMaker().make("Notes", in: parent, from: ProjectReaderTests.repository)
        let project = try await ProjectReader().describe(containing: made)

        XCTAssertEqual(project.applications.map(\.name), ["Notes"])
        XCTAssertEqual(project.applications.first?.products, ["NotesUI"])
        XCTAssertEqual(project.libraries.map(\.rootUri), [FileURI.string(ProjectReaderTests.repository.resolvingSymlinksInPath())])
    }
}
