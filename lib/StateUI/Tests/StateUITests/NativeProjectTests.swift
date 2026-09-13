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

    func testGalleryOwnsItsAcceptanceTests() {
        let repository = Fixtures.repository

        XCTAssertTrue(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("apps/Gallery/Tests/GalleryTests").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: repository.appendingPathComponent("lib/Tests").path))
    }
}
