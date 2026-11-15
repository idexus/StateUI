// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class IndexContextsTests: XCTestCase {
    /// Each host indexes in a scratch folder of its own, plain Swift in SwiftPM's; a desktop host of this machine
    /// needs no triple or SDK.
    func testEachHostIndexesApart() async {
        XCTAssertEqual(IndexContexts.scratchPath(of: nil), ".build/index-build")
        XCTAssertEqual(IndexContexts.scratchPath(of: .uikit), ".build/uikit/index-build")
        XCTAssertEqual(Set(IndexContexts.scratchPaths).count, HostFamily.allCases.count + 1)
        let gtk = await IndexContexts(tools: ToolResolver()).describe(.gtk)
        XCTAssertEqual(gtk, IndexContext(host: .gtk, scratchPath: ".build/gtk/index-build"))
    }

    /// Cleaning takes every index's scratch folder away and nothing else of the package's build.
    func testCleaningTakesEveryIndexAway() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("index-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        for folder in [".build/uikit/index-build", ".build/index-build", ".build/uikit/arm64-0"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        let removed = IndexContexts.clean([root]).map { $0.path.dropFirst(root.path.count) }.sorted()
        XCTAssertEqual(removed, ["/.build/index-build", "/.build/uikit/index-build"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".build/uikit/arm64-0").path))
    }
}
