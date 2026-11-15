// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class WorkspaceMakerTests: XCTestCase {
    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func text(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }

    /// A repository's releases are its tags of three numbers from the minimum, newest first.
    func testReleasesAreTagsOfThreeNumbersNewestFirst() async throws {
        let listing = "a\trefs/tags/0.4.0\nb\trefs/tags/0.9.1\nc\trefs/tags/v1\nd\trefs/tags/0.10.0\ne\trefs/tags/1.0.0-beta\n"
        XCTAssertEqual(ReleaseCatalog.releases(in: listing, from: "0.5.0"), ["0.10.0", "0.9.1"])

        let origin = try await GitFixture.repository(tagged: ["0.4.0", "0.5.0", "0.9.1", "0.10.0", "v2"])
        let releases = try await ReleaseCatalog().releases(of: origin.url, from: Release.oldestUsable)
        XCTAssertEqual(releases, ["0.10.0", "0.9.1", "0.5.0"])
    }

    /// A workspace building with a checkout names it by the path from the workspace, lists its first application,
    /// and ignores what builds write.
    /// A path written for a folder reads back as that folder: one beside the workspace from the workspace's own, and
    /// a whole path - a checkout on another drive, on Windows - by itself.
    func testAWrittenPathReadsBackAsItsFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("written-\(UUID().uuidString)")
        let (demo, near) = (root.appendingPathComponent("work/Demo"), root.appendingPathComponent("a/StateUI"))
        let written = ApplicationMaker.relativePath(from: demo, to: near)
        XCTAssertEqual(written, "../../a/StateUI")
        XCTAssertEqual(ApplicationMaker.folder(named: written, from: demo).path, RealPath.lexical(near).path)
        #if os(Windows)
        let far = URL(fileURLWithPath: #"D:\a\StateUI"#)
        let home = URL(fileURLWithPath: #"C:\work\Demo"#)
        XCTAssertEqual(ApplicationMaker.folder(named: ApplicationMaker.relativePath(from: home, to: far), from: home).path, far.path)
        let workspace = Workspace(folder: home, file: WorkspaceFile(library: .init(path: "D:/a/StateUI"), projects: []))
        XCTAssertEqual(workspace.library?.path, far.path)
        #else
        XCTAssertEqual(ApplicationMaker.folder(named: "/a/StateUI", from: demo).path, "/a/StateUI")
        #endif
    }

    func testAWorkspaceOfACheckoutListsItsFirstApplication() async throws {
        let parent = try folder()
        let change = try await WorkspaceMaker().make(
            "Demo", in: parent, library: .checkout(ProjectReaderTests.repository), application: "Notes")
        let demo = RealPath.of(parent).appendingPathComponent("Demo")

        let file = try WorkspaceFile.read(demo.appendingPathComponent("stateui.json"))
        XCTAssertEqual(file.projects, ["Notes"])
        XCTAssertEqual(file.library?.path, ApplicationMaker.relativePath(from: demo, to: ProjectReaderTests.repository))
        XCTAssertEqual(change.changedUris.count, 2)
        let ignored = try text(demo.appendingPathComponent(".gitignore"))
        XCTAssertTrue(ignored.contains(".build*/") && ignored.contains(".stateui/"))
        XCTAssertFalse(ignored.contains("/StateUI/"))
        let project = try await ProjectReader().describe(containing: demo)
        XCTAssertEqual(project.applications.map(\.name), ["Notes"])
    }

    /// A workspace building with a release clones it into its `StateUI/`, which its applications name and Git
    /// leaves out.
    func testAWorkspaceOfAReleaseClonesIt() async throws {
        let origin = try await GitFixture.repository(tagged: ["0.9.1"])
        let parent = try folder()
        _ = try await WorkspaceMaker().make("Demo", in: parent, library: .release("0.9.1", repository: origin.url), application: "Notes")
        let demo = RealPath.of(parent).appendingPathComponent("Demo")

        XCTAssertNotNil(Checkout(at: demo.appendingPathComponent("StateUI")))
        XCTAssertEqual(try WorkspaceFile.read(demo.appendingPathComponent("stateui.json")).library?.path, "StateUI")
        XCTAssertTrue(try text(demo.appendingPathComponent("Notes/Package.swift")).contains(#"path: "../StateUI")"#))
        XCTAssertTrue(try text(demo.appendingPathComponent(".gitignore")).contains("/StateUI/"))
    }

    /// A name no build tool takes, a folder holding files, and a release older than the tool builds with are refused,
    /// leaving nothing.
    func testWhatCannotBeIsRefusedLeavingNothing() async throws {
        let parent = try folder()
        for (name, library, code) in [
            ("Bad Name", WorkspaceMaker.Library.checkout(ProjectReaderTests.repository), ToolingErrorCode.invalidName),
            ("Old", .release("0.4.0", repository: "file:///nowhere"), .incompatibleLibrary),
        ] {
            do {
                _ = try await WorkspaceMaker().make(name, in: parent, library: library, application: nil)
                XCTFail("\(name) was made")
            } catch let error as ToolingError {
                XCTAssertEqual(error.code, code, name)
            }
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: parent.path), [])
    }

    /// A library changed is named by every listed application's manifest and by the file; a manifest naming its
    /// checkout in another form is refused, and nothing is rewritten.
    func testALibraryChangedRewritesEveryManifest() async throws {
        let origin = try await GitFixture.repository(tagged: ["0.9.1"])
        let parent = try folder()
        _ = try await WorkspaceMaker().make(
            "Demo", in: parent, library: .checkout(ProjectReaderTests.repository), application: "Notes")
        let demo = RealPath.of(parent).appendingPathComponent("Demo")
        var workspace = try XCTUnwrap(try Workspace.nearest(from: demo))

        let rewritten = try workspace.use(origin.folder)
        let manifest = try text(demo.appendingPathComponent("Notes/Package.swift"))
        let path = ApplicationMaker.relativePath(from: demo.appendingPathComponent("Notes"), to: origin.folder)
        XCTAssertTrue(manifest.contains("path: \"\(path)\")"), manifest)
        XCTAssertTrue(manifest.contains("path: \"\(path)/lib/StateUI/StateUI.Testing\")"), manifest)
        XCTAssertEqual(rewritten.map(\.lastPathComponent), ["Package.swift", "stateui.json"])

        let other = demo.appendingPathComponent("Notes/Package.swift")
        try manifest.replacingOccurrences(of: "\"StateUIRoot\", path:", with: "\"StateUIRoot\",  path:").write(to: other, atomically: true, encoding: .utf8)
        let before = try text(demo.appendingPathComponent("stateui.json"))
        XCTAssertThrowsError(try workspace.use(ProjectReaderTests.repository)) {
            XCTAssertEqual(($0 as? ToolingError)?.code, .invalidConfiguration)
        }
        XCTAssertEqual(try text(demo.appendingPathComponent("stateui.json")), before)
    }

    /// A release replaces a workspace's clone only where the clone holds no changes of its own.
    func testAReleaseReplacesOnlyACleanClone() async throws {
        let origin = try await GitFixture.repository(tagged: ["0.9.1", "0.10.0"])
        let parent = try folder()
        _ = try await WorkspaceMaker().make("Demo", in: parent, library: .release("0.9.1", repository: origin.url), application: nil)
        let demo = RealPath.of(parent).appendingPathComponent("Demo")

        _ = try await ToolingService().useLibrary(in: demo, checkout: nil, release: "0.10.0", repository: origin.url)
        try "changed".write(to: demo.appendingPathComponent("StateUI/Package.swift"), atomically: true, encoding: .utf8)
        do {
            _ = try await ToolingService().useLibrary(in: demo, checkout: nil, release: "0.9.1", repository: origin.url)
            XCTFail("a clone with changes was replaced")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .alreadyExists)
        }
        XCTAssertEqual(try text(demo.appendingPathComponent("StateUI/Package.swift")), "changed")
    }
}
