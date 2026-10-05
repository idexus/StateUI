// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import WASILibc
import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance

/// What this host's conformance runs write into the library's `exports` folder: the verdicts its cases gave - held
/// to the family's file, or written there on a run with STATEUI_UPDATE_EXPORTS=1, then read in the diff. The page
/// reaches no file: the controller beside the browser reads and writes them (Testing/JavaScript/run-in-browser.mjs).
@MainActor
enum WebExports {
    /// The revision `family`'s verdicts on this host stand at.
    /// Design: docs/design/contracts/dictionary.md#fresh-verdicts
    static func revision(of family: String) -> String {
        HostVerdict.revision(of: family, on: "web", in: revisions)
    }

    /// The revision file's lines, read once a run.
    private static let revisions: String = {
        // No file is no revision: every family would read as standing at 1, whatever was raised.
        guard let text = WebBrowser.ask([("read", .words("lib/StateUI/StateUI.Conformance/revisions.txt"))]) else {
            preconditionFailure("no lib/StateUI/StateUI.Conformance/revisions.txt")
        }
        return text
    }()

    /// Whether the run leaves `family` out: it is asked for the stale families alone (STATEUI_STALE_ONLY=1), and
    /// the verdict file at `path` here stands at the family's revision.
    static func skips(_ family: String, at path: String) -> Bool {
        guard let only = getenv("STATEUI_STALE_ONLY"), String(cString: only) == "1" else { return false }
        let held = WebBrowser.ask([("read", .words("lib/StateUI/exports/" + path))])
        return !HostVerdict.isStale(held, family: family, on: "web", in: revisions)
    }

    /// Holds `text` to `path` here - or writes it there, where the run is asked to.
    static func hold(_ text: String, at path: String, file: StaticString = #filePath, line: UInt = #line) {
        let held = WebBrowser.ask([("hold", .words(path)), ("text", .words(text))]) ?? ""
        // The revision a run was made at is the run's own: two runs at other revisions compare by their verdicts.
        XCTAssertEqual(
            HostVerdict.withoutRevision(text), HostVerdict.withoutRevision(held),
            "\(path) in lib/StateUI/exports says otherwise: what this run says changed - run the suite again with "
                + "STATEUI_UPDATE_EXPORTS=1 and read the diff - or something stopped working.",
            file: file, line: line)
    }

    /// Runs `family` on the Web, and holds its verdicts to the family's file of the Web's marks here.
    static func conform(_ family: any ConformanceFamily.Type, file: StaticString = #filePath, line: UInt = #line) {
        let path = "marks/web/\(family.name).txt"
        guard !skips(family.name, at: path) else { return }
        let verdicts = Conformance.run(
            family, on: WebDriver(), report: { XCTFail($0.message, file: $0.file, line: $0.line) })
        hold(HostVerdict.text(verdicts, revision: revision(of: family.name)), at: path, file: file, line: line)
    }
}
