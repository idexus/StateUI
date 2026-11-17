// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ProjectReaderTests: XCTestCase {
    /// The StateUI repository this test stands in.
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// An application's file, as `stateui new` writes one.
    private static let mark = #"{"build":1,"identifier":"com.example.demo","schemaVersion":1,"version":"1.0.0"}"#

    private func package(_ files: [String: String]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)").appendingPathComponent("Demo")
        for (path, text) in files {
            let file = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        }
        return folder
    }

    /// The StateUI repository is a workspace of its applications - each with its heads, products and tests - building
    /// with the checkout itself, whose release is the library's, and whose commit Git says where it is a working tree.
    func testACheckoutIsAProjectOfItsApplications() async throws {
        let project = try await ProjectReader().describe(containing: Self.repository)

        XCTAssertEqual(project.rootUri, FileURI.string(Self.repository.resolvingSymlinksInPath()))
        XCTAssertEqual(project.applications.map(\.id), ["apps/Gallery", "apps/HelloWorld"])
        let hello = try XCTUnwrap(project.applications.last)
        XCTAssertEqual(hello.name, "HelloWorld")
        XCTAssertEqual([hello.identifier, hello.displayName, hello.version], ["com.stateui.helloworld", "HelloWorld", Release.version])
        XCTAssertEqual(project.applications.first?.displayName, "StateUI Gallery")
        XCTAssertEqual(hello.build, 1)
        XCTAssertEqual(hello.declaredHosts, HostFamily.allCases)
        XCTAssertEqual(hello.products, ["HelloWorldUI"])
        XCTAssertEqual(hello.testSuites, ["HelloWorldTests"])
        XCTAssertEqual(hello.libraryUri, project.rootUri)
        XCTAssertEqual(project.libraries.map(\.rootUri), [project.rootUri])
        XCTAssertEqual(project.libraries.first?.release, Release.version)
        let isWorkingTree = FileManager.default.fileExists(atPath: Self.repository.appendingPathComponent(".git").path)
        XCTAssertEqual(project.libraries.first?.revision?.count, isWorkingTree ? 40 : nil)
    }

    /// The project is the nearest folder up that holds an application: inside an application, the application.
    func testTheNearestApplicationIsTheProject() async throws {
        let sources = Self.repository.appendingPathComponent("apps/HelloWorld/Sources")
        let project = try await ProjectReader().describe(containing: sources)

        XCTAssertEqual(project.applications.map(\.id), ["."])
        XCTAssertEqual(project.applications.map(\.name), ["HelloWorld"])
    }

    /// A workspace's applications are the ones its `stateui-workspace.json` lists, in any folders; inside one of them,
    /// the project is that application, standing in its workspace.
    func testAWorkspaceIsTheApplicationsItsFileLists() async throws {
        let root = try package([
            "a/One/Package.swift": "", "a/One/stateui.json": Self.mark, "a/One/Platforms/AppKit/Package.swift": "",
            "b/c/Two/Package.swift": "", "b/c/Two/stateui.json": Self.mark,
            "b/c/Two/Platforms/Android/Package.swift": "",
            "Unlisted/Package.swift": "", "Unlisted/stateui.json": Self.mark, "Unlisted/Platforms/GTK/Package.swift": "",
        ])
        try WorkspaceFile(projects: ["b/c/Two", "a/One"])
            .write(to: root.appendingPathComponent("stateui-workspace.json"))
        let workspace = try XCTUnwrap(try Workspace.nearest(from: root.appendingPathComponent("b")))
        XCTAssertEqual(try workspace.applications().map(\.lastPathComponent), ["One", "Two"])
        XCTAssertEqual(ProjectReader.application(holding: root.appendingPathComponent("a/One/Platforms"))?.lastPathComponent, "One")
        XCTAssertNil(ProjectReader.application(holding: root))
    }

    /// A workspace file listing a folder that is no application, or saying what the tool does not read, is refused
    /// by what and where.
    func testAWorkspaceFileIsReadWhole() throws {
        let root = try package(["notes/Package.swift": "", "notes/Platforms/AppKit/Package.swift": ""])
        let file = root.appendingPathComponent("stateui-workspace.json")
        try WorkspaceFile(projects: ["notes"]).write(to: file)
        XCTAssertThrowsError(try Workspace.nearest(from: root)?.applications()) {
            XCTAssertEqual(($0 as? ToolingError)?.code, .invalidConfiguration)
            XCTAssertTrue(($0 as? ToolingError)?.message.contains("stateui.json") == true)
        }
        try #"{"schemaVersion":1,"projects":[],"profiles":{}}"#.write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Workspace.nearest(from: root)) {
            XCTAssertEqual(($0 as? ToolingError)?.code, .invalidConfiguration)
            XCTAssertTrue(($0 as? ToolingError)?.message.contains("/profiles") == true)
        }
        try #"{"schemaVersion":2,"projects":[]}"#.write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Workspace.nearest(from: root))
        try #"{"schemaVersion":1,"projects":["notes"],"startup":"notes"}"#.write(to: file, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try Workspace.nearest(from: root)) {
            XCTAssertTrue(($0 as? ToolingError)?.message.contains("/startup") == true, "the workspace's file says no startup")
        }
        try WorkspaceFile(projects: ["notes"]).write(to: file)
        try WorkspaceSettings(startup: "elsewhere").write(to: WorkspaceSettings.file(in: root))
        XCTAssertThrowsError(try Workspace.nearest(from: root)?.startup()) {
            XCTAssertEqual(($0 as? ToolingError)?.code, .invalidConfiguration)
            XCTAssertTrue(($0 as? ToolingError)?.message.contains("elsewhere") == true)
        }
    }

    /// The file is written the same every time: keys and projects sorted, a line break at its end.
    func testAWorkspaceFileIsWrittenTheSameEveryTime() throws {
        let file = try package(["x": ""]).appendingPathComponent("stateui-workspace.json")
        try WorkspaceFile(library: .init(path: "StateUI"), projects: ["b", "a"]).write(to: file)
        XCTAssertEqual(
            try String(contentsOf: file, encoding: .utf8),
            "{\n  \"library\" : {\n    \"path\" : \"StateUI\"\n  },\n  \"projects\" : [\n    \"a\",\n    \"b\"\n  ],\n"
                + "  \"schemaVersion\" : 1\n}\n")
    }

    /// An application is a folder holding its `stateui.json`: a package with heads and none is no application, and
    /// the folder holding the file is one wherever its heads are.
    func testAnApplicationIsAFolderHoldingItsFile() throws {
        let root = try package([
            "Heads/Package.swift": "", "Heads/Platforms/AppKit/Package.swift": "",
            "Marked/Package.swift": "", "Marked/stateui.json": Self.mark,
        ])
        XCTAssertNil(ProjectReader.application(holding: root.appendingPathComponent("Heads/Platforms")))
        XCTAssertEqual(ProjectReader.application(holding: root.appendingPathComponent("Marked"))?.lastPathComponent, "Marked")
    }

    /// An application's file is read whole and checked: what it does not say, a field it has no place for, and an
    /// identifier, version or build some platform refuses are each refused by what and where.
    func testAnApplicationFileIsReadWhole() throws {
        let file = try package(["x": ""]).appendingPathComponent("stateui.json")
        let refused = { (json: String, said: String) in
            try json.write(to: file, atomically: true, encoding: .utf8)
            XCTAssertThrowsError(try ApplicationFile.read(file), json) {
                XCTAssertEqual(($0 as? ToolingError)?.code, .invalidConfiguration, json)
                XCTAssertTrue(($0 as? ToolingError)?.message.contains(said) == true, "\($0)")
            }
        }
        try refused(#"{"build":1,"identifier":"pl.example.notes","schemaVersion":1}"#, "version")
        try refused(#"{"build":1,"identifier":"pl.example.notes","schemaVersion":1,"version":"1","title":"N"}"#, "/title")
        try refused(#"{"build":1,"identifier":"notes","schemaVersion":1,"version":"1"}"#, "identifier")
        try refused(#"{"build":1,"identifier":"pl.my-company.notes","schemaVersion":1,"version":"1"}"#, "identifier")
        try refused(#"{"build":1,"identifier":"pl.example.2notes","schemaVersion":1,"version":"1"}"#, "identifier")
        try refused(#"{"build":1,"identifier":"pl.example.notes","schemaVersion":1,"version":"1.0.0.0"}"#, "version")
        try refused(#"{"build":1,"identifier":"pl.example.notes","schemaVersion":1,"version":"1.02"}"#, "version")
        try refused(#"{"build":0,"identifier":"pl.example.notes","schemaVersion":1,"version":"1"}"#, "build")
        try refused(#"{"build":1,"identifier":"pl.example.notes","name":" ","schemaVersion":1,"version":"1"}"#, "name")
        try refused(#"{"build":1,"identifier":"pl.example.notes","schemaVersion":2,"version":"1"}"#, "schemaVersion")

        try ApplicationFile(identifier: "pl.example.notes", version: "1.10.0", build: 7).write(to: file)
        XCTAssertEqual(
            try String(contentsOf: file, encoding: .utf8),
            "{\n  \"build\" : 7,\n  \"identifier\" : \"pl.example.notes\",\n  \"schemaVersion\" : 1,\n"
                + "  \"version\" : \"1.10.0\"\n}\n")
        XCTAssertEqual(try ApplicationFile.read(file), ApplicationFile(identifier: "pl.example.notes", version: "1.10.0", build: 7))
    }

    /// The hosts a package has heads for: a package of its own in `Platforms/<Host>`.
    func testAPackagesHostsAreItsHeads() throws {
        let folder = try package([
            "Package.swift": "", "Platforms/UIKit/Package.swift": "", "Platforms/Android/Package.swift": "",
            "Platforms/GTK/main.swift": "",
        ])
        XCTAssertEqual(ProjectReader.hosts(of: folder), [.uikit, .android])
    }

    /// No application in a folder or above it, and no workspace, is no project.
    func testAFolderWithoutApplicationsIsNoProject() async throws {
        let folder = try package(["notes.txt": ""])
        do {
            _ = try await ProjectReader().describe(containing: folder)
            XCTFail("a project was found")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .projectNotFound)
        }
    }

    /// A manifest SwiftPM cannot read is a tool's failure, saying where and what SwiftPM said.
    func testAManifestSwiftPMCannotReadIsAToolFailure() async throws {
        let folder = try package([
            "Package.swift": "// swift-tools-version:6.4\nimport PackageDescription\nlet package = Package(nonsense)\n",
            "Platforms/AppKit/Package.swift": "", "stateui.json": Self.mark,
        ])
        do {
            _ = try await ProjectReader().describe(containing: folder)
            XCTFail("a broken manifest was read")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .toolFailed)
            XCTAssertTrue(error.message.contains(folder.lastPathComponent), error.message)
        }
    }

    /// Swift that cannot be found is a missing toolchain, saying how to name it.
    func testSwiftThatCannotBeFoundIsAMissingToolchain() async throws {
        let folder = try package(["Package.swift": "", "Platforms/AppKit/Package.swift": "", "stateui.json": Self.mark])
        let reader = ProjectReader(tools: ToolResolver(environment: ["SWIFT_BIN": "/no/such/swift"]))
        do {
            _ = try await reader.describe(containing: folder)
            XCTFail("swift was found")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .missingToolchain)
            XCTAssertTrue(error.message.contains("SWIFT_BIN"), error.message)
        }
    }
}
