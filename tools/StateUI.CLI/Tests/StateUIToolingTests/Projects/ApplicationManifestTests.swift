// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class ApplicationManifestTests: XCTestCase {
    /// Every manifest of an application - its own and each head's - names the checkout by the path from its own
    /// folder, written once even where the new path begins as the old one did; a head's path to the application
    /// stays as it was.
    func testEveryManifestNamesTheCheckoutOnceByThePathFromItsFolder() throws {
        let root = RealPath.of(FileManager.default.temporaryDirectory).appendingPathComponent("manifests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let application = root.appendingPathComponent("a/Notes"), head = application.appendingPathComponent("Platforms/AppKit")
        let checkout = root.appendingPathComponent("StateUI")
        for folder in [head, checkout] { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        try """
            .package(name: "StateUIRoot", path: "../.."),
            .package(name: "StateUITesting", path: "../../lib/StateUI/StateUI.Testing"),
            """.write(to: application.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try """
            .package(name: "NotesUI", path: "../..", traits: ["AppKit"]),
            .package(name: "StateUIRoot", path: "../../../.."),
            .package(name: "StateUIHead", path: "../../../../lib/StateUI.Head", traits: ["AppKit"]),
            """.write(to: head.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let named = try ApplicationManifest.naming(checkout, in: application)

        XCTAssertEqual(named.map(\.manifest.path), [application, head].map { $0.appendingPathComponent("Package.swift").path })
        XCTAssertEqual(named.first?.text, """
            .package(name: "StateUIRoot", path: "../../StateUI"),
            .package(name: "StateUITesting", path: "../../StateUI/lib/StateUI/StateUI.Testing"),
            """)
        XCTAssertEqual(named.last?.text, """
            .package(name: "NotesUI", path: "../..", traits: ["AppKit"]),
            .package(name: "StateUIRoot", path: "../../../../StateUI"),
            .package(name: "StateUIHead", path: "../../../../StateUI/lib/StateUI.Head", traits: ["AppKit"]),
            """)
    }
}
