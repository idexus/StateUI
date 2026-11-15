// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class EditorIntegrationTests: XCTestCase {
    private func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("integration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// A conformance run's selection is written as one key: the stale families, the ones named, or every one.
    func testASelectionIsOneKey() throws {
        for (selection, written) in [(ConformanceSelection.changed, #"{"changed":true}"#), (.all, #"{"all":true}"#),
                                     (.families(["Button"]), #"{"families":["Button"]}"#)] {
            XCTAssertEqual(String(decoding: try JSONEncoder().encode(selection), as: UTF8.self), written)
            XCTAssertEqual(try JSONDecoder().decode(ConformanceSelection.self, from: Data(written.utf8)), selection)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(ConformanceSelection.self, from: Data(#"{"changed":false}"#.utf8)))
    }

    /// A checkout with no extension's sources packages none.
    func testNoSourcesPackageNothing() async throws {
        do {
            _ = try await EditorIntegration(checkout: try folder()).package(.vscode, reporter: BuildReporter())
            XCTFail("packaged")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .projectNotFound)
        }
    }

    /// An install holds only where the editor lists the extension at its version afterwards.
    func testAnInstallIsFoundListedAtItsVersion() async throws {
        #if os(Windows)
        throw XCTSkip("a stand-in editor is a shell script")
        #else
        let root = try folder()
        let editor = root.appendingPathComponent("code")
        try """
        #!/bin/sh
        case "$1" in --list-extensions) echo other.one@1.0.0; echo Idexus.StateUI@0.8.5 ;; esac
        """.write(to: editor, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: editor.path)
        let made = EditorExtension(artifactUri: FileURI.string(root.appendingPathComponent("stateui-0.8.5.vsix")),
                                   extensionId: "idexus.stateui", version: "0.8.5")

        let installed = try await EditorIntegration.install(made, with: editor, reporter: BuildReporter())
        XCTAssertEqual(installed, made)

        var newer = made
        newer.version = "0.8.6"
        do {
            _ = try await EditorIntegration.install(newer, with: editor, reporter: BuildReporter())
            XCTFail("an extension the editor does not list at its version was taken as installed")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .toolFailed)
            XCTAssertTrue(error.message.contains("idexus.stateui@0.8.6"), error.message)
        }
        #endif
    }
}
