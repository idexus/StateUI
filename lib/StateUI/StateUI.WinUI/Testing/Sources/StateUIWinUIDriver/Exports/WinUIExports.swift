// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@_spi(Host) import StateUI

/// What this host's runs write into the repository's `exports`: what its runtime realizes, and what its passing
/// tests proved - held to the file, or written into it on a run with STATEUI_UPDATE_EXPORTS=1, then read in the
/// diff.
enum WinUIExports {
    /// The repository, seven folders above this file's.
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // Exports
        .deletingLastPathComponent()    // StateUIWinUIDriver
        .deletingLastPathComponent()    // Sources
        .deletingLastPathComponent()    // Testing
        .deletingLastPathComponent()    // StateUI.WinUI
        .deletingLastPathComponent()    // StateUI
        .deletingLastPathComponent()    // lib
        .deletingLastPathComponent()    // the repository

    /// The folder the files stand in: `lib/StateUI/exports`.
    static let folder = repository.appendingPathComponent("lib/StateUI/exports")

    /// The revisions the families' verdicts stand at.
    static let revisionFile = repository.appendingPathComponent("lib/StateUI/StateUI.Conformance/revisions.txt")

    /// The revision `family`'s verdicts on this host stand at, as `lib/StateUI/StateUI.Conformance/revisions.txt` says.
    /// Design: docs/design/contracts/dictionary.md#fresh-verdicts
    static func revision(of family: String) -> String {
        HostVerdict.revision(of: family, on: "winui", in: revisions)
    }

    /// Whether the run leaves `family` out: it is asked for the stale families alone (STATEUI_STALE_ONLY=1), and
    /// the verdict file at `path` under `exports` stands at the family's revision.
    static func skips(_ family: String, at path: String) -> Bool {
        guard ProcessInfo.processInfo.environment["STATEUI_STALE_ONLY"] == "1" else { return false }
        let held = try? String(contentsOf: folder.appendingPathComponent(path), encoding: .utf8)
        return !HostVerdict.isStale(held, family: family, on: "winui", in: revisions)
    }

    /// The revision file's lines.
    private static var revisions: String {
        // No file is no revision: every family would read as standing at 1, whatever was raised.
        guard let text = try? String(contentsOf: revisionFile, encoding: .utf8) else {
            preconditionFailure("no \(revisionFile.path)")
        }
        return text
    }

    /// Holds `text` to `path` under `exports` - or writes it there, where the run is asked to.
    static func hold(_ text: String, at path: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let url = folder.appendingPathComponent(path)
        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_EXPORTS"] == "1" {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        // The revision a run was made at is the run's own: two runs at other revisions compare by their verdicts.
        let held = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        XCTAssertEqual(
            HostVerdict.withoutRevision(text), HostVerdict.withoutRevision(held),
            "lib/StateUI/exports/\(path) says otherwise: what this run says changed - run the suite again with "
                + "STATEUI_UPDATE_EXPORTS=1 and read the diff - or something stopped working.",
            file: file, line: line)
    }
}
