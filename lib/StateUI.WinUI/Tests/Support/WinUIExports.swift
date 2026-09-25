// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// What this host's runs write into the repository's `exports`: what its runtime realizes, and what its passing
/// tests proved - held to the file, or written into it on a run with STATEUI_UPDATE_EXPORTS=1, then read in the
/// diff.
enum WinUIExports {
    /// `exports`, beside `lib`.
    static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // Support
        .deletingLastPathComponent()    // Tests
        .deletingLastPathComponent()    // StateUI.WinUI
        .deletingLastPathComponent()    // lib
        .deletingLastPathComponent()    // the repository
        .appendingPathComponent("exports")

    /// Holds `text` to `path` under `exports` - or writes it there, where the run is asked to.
    static func hold(_ text: String, at path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let url = folder.appendingPathComponent(path)
        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        let held = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertEqual(
            text, held,
            "exports/\(path) says otherwise: what this run says changed - run the suite again with "
                + "STATEUI_UPDATE_EXPORTS=1 and read the diff - or something stopped working.",
            file: file, line: line)
    }
}
