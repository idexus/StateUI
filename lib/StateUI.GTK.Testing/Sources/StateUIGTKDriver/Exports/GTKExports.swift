// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance

/// What this host's runs write into an `exports` folder - the library's beside `lib`, or a component's in its own
/// package: what its runtime realizes, and what its passing tests proved - held to the file, or written into it on a
/// run with STATEUI_UPDATE_EXPORTS=1, then read in the diff.
struct GTKExports {
    /// The folder the files stand in.
    let folder: URL

    /// The revisions the families' verdicts stand at: each file's lines, read together.
    let revisionFiles: [URL]

    /// The repository, five folders above this file's.
    static let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // Exports
        .deletingLastPathComponent()    // StateUIGTKDriver
        .deletingLastPathComponent()    // Sources
        .deletingLastPathComponent()    // StateUI.GTK.Testing
        .deletingLastPathComponent()    // lib
        .deletingLastPathComponent()    // the repository

    /// The library's: `exports` beside `lib`, at the revisions of `lib/StateUI.Conformance/revisions.txt`.
    static let library = GTKExports(
        folder: repository.appendingPathComponent("exports"),
        revisionFiles: [repository.appendingPathComponent("lib/StateUI.Conformance/revisions.txt")])

    /// A component's, in its folder laid out as StateUI is: `exports` there, at the revisions of its conformance
    /// package's `revisions.txt` - its family's - and the library's, for the families of the tiers its element wears.
    static func component(_ folder: URL, named name: String) -> GTKExports {
        GTKExports(
            folder: folder.appendingPathComponent("exports"),
            revisionFiles: [folder.appendingPathComponent("\(name).Conformance/revisions.txt")] + library.revisionFiles)
    }

    /// The revision `family`'s verdicts on this host stand at.
    /// Design: docs/design/contracts/dictionary.md#fresh-verdicts
    func revision(of family: String) -> String {
        HostVerdict.revision(of: family, on: "gtk", in: revisions)
    }

    /// Whether the run leaves `family` out: it is asked for the stale families alone (STATEUI_STALE_ONLY=1), and
    /// the verdict file at `path` here stands at the family's revision.
    func skips(_ family: String, at path: String) -> Bool {
        guard ProcessInfo.processInfo.environment["STATEUI_STALE_ONLY"] == "1" else { return false }
        let held = try? String(contentsOf: folder.appendingPathComponent(path), encoding: .utf8)
        return !HostVerdict.isStale(held, family: family, on: "gtk", in: revisions)
    }

    /// The revision files' lines, read together.
    private var revisions: String {
        revisionFiles.map { url in
            // No file is no revision: every family would read as standing at 1, whatever was raised.
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { preconditionFailure("no \(url.path)") }
            return text
        }.joined(separator: "\n")
    }

    /// Holds `text` to `path` here - or writes it there, where the run is asked to.
    func hold(_ text: String, at path: String, file: StaticString = #filePath, line: UInt = #line) throws {
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
            "\(path) in \(folder.path) says otherwise: what this run says changed - run the suite again with "
                + "STATEUI_UPDATE_EXPORTS=1 and read the diff - or something stopped working.",
            file: file, line: line)
    }

    /// Runs `family` on GTK - for `element` alone where one is named, as a component runs a tier's - and holds its
    /// verdicts to the family's file of GTK's marks here.
    @MainActor
    func conform(
        _ family: any ConformanceFamily.Type, element: String? = nil, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let path = "marks/gtk/\(family.name).txt"
        guard !skips(family.name, at: path) else { return }
        let verdicts = Conformance.run(
            family, element: element, on: GTKDriver(), report: { XCTFail($0.message, file: $0.file, line: $0.line) })
        XCTAssertNoThrow(
            try hold(HostVerdict.text(verdicts, revision: revision(of: family.name)), at: path), file: file, line: line)
    }
}
