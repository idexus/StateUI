// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

final class NativeProjectTests: XCTestCase {
    func testEveryApplicationSeparatesSharedSourcesFromItsAppKitEntryPoint() throws {
        for name in ["Gallery", "HelloWorld"] {
            let app = Fixtures.repository.appendingPathComponent("apps/\(name)")
            for relative in ["Package.swift", "Sources", "Platforms/AppKit/main.swift", "Resources"] {
                XCTAssertTrue(
                    FileManager.default.fileExists(
                        atPath: app.appendingPathComponent(relative).path),
                    "\(name) is missing \(relative)")
            }

            let manifest = try String(
                contentsOf: app.appendingPathComponent("Package.swift"),
                encoding: .utf8)
            XCTAssertTrue(manifest.contains("name: \"\(name)UI\""))
            XCTAssertTrue(manifest.contains("name: \"\(name)AppKit\""))
            XCTAssertTrue(manifest.contains("name: \"StateUIAppKit\""))

            let entry = try String(
                contentsOf: app.appendingPathComponent("Platforms/AppKit/main.swift"),
                encoding: .utf8)
            XCTAssertTrue(entry.contains("import StateUIAppKit"))
            XCTAssertTrue(entry.contains("StateUIAppKit.run("))
        }
    }

    func testTheCompatibilityImplementationExistsOnlyInTheArchive() {
        let pairs = [
            ("StateUI.slnx", "_old/StateUI.slnx"),
            ("lib/StateUI.Runtime/StateUI.Runtime.csproj", "_old/src/StateUI.Runtime/StateUI.Runtime.csproj"),
            ("lib/Tests/StateUIRuntime.Tests/StateUIRuntime.Tests.csproj", "_old/src/Tests/StateUIRuntime.Tests/StateUIRuntime.Tests.csproj"),
            ("apps/Gallery/Gallery.csproj", "_old/apps/Gallery/Gallery.csproj"),
            ("apps/HelloWorld/HelloWorld.csproj", "_old/apps/HelloWorld/HelloWorld.csproj"),
        ]

        for (active, archived) in pairs {
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: Fixtures.repository.appendingPathComponent(active).path))
            XCTAssertTrue(FileManager.default.fileExists(
                atPath: Fixtures.repository.appendingPathComponent(archived).path))
        }
    }

    /// The former toolkit stays in the archive.
    ///
    /// A sample, a comment or a document that names it describes StateUI
    /// through something StateUI is not. The word is assembled here so this
    /// guard does not find itself. Allowed to hold it: the guard that keeps it
    /// out of the editor configuration, and the working agreement - ignored by
    /// git - which tells an agent what the archive is so that it leaves it
    /// alone.
    func testNothingOutsideTheArchiveNamesTheFormerToolkit() throws {
        let word = "ma" + "ui"
        let repository = Fixtures.repository
        let scratch: Set<String> = ["_old", ".build", ".git", ".swiftpm", "obj", "bin"]
        let allowed: Set<String> = [
            "lib/StateUI/Tests/StateUITests/NativeConfigurationTests.swift",
            "AGENTS.md", "CLAUDE.md",
        ]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(
            at: repository, includingPropertiesForKeys: [.isDirectoryKey]))
        var offenders: [String] = []

        for case let url as URL in enumerator {
            if scratch.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }

            let relative = String(url.path.dropFirst(repository.path.count + 1))
            guard !allowed.contains(relative),
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true,
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

            for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.lowercased().contains(word) {
                offenders.append("\(relative):\(number + 1)")
            }
        }

        XCTAssertEqual(offenders, [], "these name the former toolkit outside _old/")
    }

    func testGalleryOwnsItsAcceptanceTests() {
        let repository = Fixtures.repository

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("apps/Gallery/Tests/GalleryTests").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("lib/Tests").path))
    }
}
