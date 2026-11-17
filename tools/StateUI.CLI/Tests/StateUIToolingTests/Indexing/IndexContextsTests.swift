// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class IndexContextsTests: XCTestCase {
    /// Each host indexes in a scratch folder of its own, plain Swift in SwiftPM's, an application's package with the
    /// host's trait; a desktop host of this machine needs no triple or SDK.
    func testEachHostIndexesApart() async {
        XCTAssertEqual(IndexContexts.scratchPath(of: nil), ".build/index-build")
        XCTAssertEqual(IndexContexts.scratchPath(of: .uikit), ".build/uikit/index-build")
        XCTAssertEqual(Set(IndexContexts.scratchPaths).count, HostFamily.allCases.count + 1)
        let gtk = await IndexContexts(tools: ToolResolver()).describe(.gtk)
        XCTAssertEqual(gtk, IndexContext(host: .gtk, trait: "GTK", scratchPath: ".build/gtk/index-build"))
        let plain = await IndexContexts(tools: ToolResolver()).describe(nil)
        XCTAssertEqual(plain, IndexContext(host: nil, scratchPath: ".build/index-build"))
    }

    /// Cleaning takes every index's scratch folder away - the application's and its heads' packages' - and nothing else
    /// of their builds.
    func testCleaningTakesEveryIndexAway() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("index-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        for folder in [".build/uikit/index-build", ".build/index-build", ".build/uikit/arm64-0",
                       "Platforms/UIKit/.build/uikit/index-build", "Platforms/UIKit/.build/uikit/arm64-0"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        let removed = IndexContexts.clean([root]).map { $0.path.dropFirst(root.path.count) }.sorted()
        XCTAssertEqual(removed, ["/.build/index-build", "/.build/uikit/index-build", "/Platforms/UIKit/.build/uikit/index-build"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(".build/uikit/arm64-0").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Platforms/UIKit/.build/uikit/arm64-0").path))
    }
}
