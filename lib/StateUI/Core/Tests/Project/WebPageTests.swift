// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The page `.scripts/Web/page.sh` lays out for a Web head: the library's
/// `index.html` with the application's names in place of its marks, and what
/// the head's `Page` folder adds to it.
final class WebPageTests: XCTestCase {
    /// A head's `Page/head.html` stands in the page's head as written - the
    /// characters a substitution reads as its own included - and its `<title>`
    /// is the page's only one.
    func testTheHeadsOwnHeadStandsInThePageAsWritten() throws {
        let head = #"""
            <title>Notes - kept & found</title>
            <meta name="description" content="Notes \ kept # and / found &amp; read">
            <link rel="canonical" href="https://example.com/notes/#top">
            """#

        let page = try layPage(head: head)

        XCTAssertTrue(page.contains(head), page)
        XCTAssertEqual(page.components(separatedBy: "<title>").count - 1, 1, page)
        XCTAssertFalse(page.contains("{{"), page)
    }

    /// A page whose head names no title is named after its application, with
    /// or without a head of its own.
    func testAPageIsNamedAfterItsApplicationUnlessItsHeadNamesIt() throws {
        let head = #"<meta name="description" content="Notes, kept.">"#

        let described = try layPage(head: head)
        XCTAssertTrue(described.contains(head), described)
        XCTAssertTrue(described.contains("<title>Notes</title>"), described)

        let plain = try layPage(head: nil)
        XCTAssertTrue(plain.contains("<title>Notes</title>"), plain)
        XCTAssertFalse(plain.contains("{{"), plain)
    }

    /// A script of the `Page` folder is laid beside the page and loaded once;
    /// the head's own head is written into the page, not laid beside it.
    func testAPageScriptIsLoadedOnceAndTheHeadIsNotLaidBeside() throws {
        let page = try layPage(head: "<meta name=\"robots\" content=\"index\">", scripts: ["notes.js"])

        XCTAssertEqual(page.components(separatedBy: "src=\"./notes.js?v=").count - 1, 1, page)
        XCTAssertTrue(FileManager.default.fileExists(atPath: site.appendingPathComponent("notes.js").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: site.appendingPathComponent("head.html").path))
    }

    // MARK: - Support

    private var folder: URL!
    private var site: URL { folder.appendingPathComponent("site") }

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("WebPageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Lays out the page of an application named Notes, its module an empty
    /// file, and answers its `index.html`.
    private func layPage(head: String?, scripts: [String] = []) throws -> String {
        let application = folder.appendingPathComponent("Notes")
        let page = application.appendingPathComponent("Platforms/Web/Page")
        let products = folder.appendingPathComponent("products")
        try FileManager.default.createDirectory(at: page, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: products, withIntermediateDirectories: true)
        try Data().write(to: products.appendingPathComponent("NotesWeb.wasm"))
        if let head {
            try Data(head.utf8).write(to: page.appendingPathComponent("head.html"))
        }
        for script in scripts {
            try Data("// \(script)\n".utf8).write(to: page.appendingPathComponent(script))
        }

        let (status, output) = try run(
            SourceTree.repository.appendingPathComponent(".scripts/Web/page.sh"),
            [application.path, products.path, site.path])
        XCTAssertEqual(status, 0, output)

        return try String(contentsOf: site.appendingPathComponent("index.html"), encoding: .utf8)
    }

    /// Runs a bash script and collects what it said, standard error included.
    /// Skipped where there is no bash: the Web head is built on macOS and Linux.
    private func run(
        _ script: URL, _ arguments: [String]
    ) throws -> (status: Int32, output: String) {
        let bash = URL(fileURLWithPath: "/bin/bash")

        guard FileManager.default.fileExists(atPath: bash.path) else {
            throw XCTSkip("no /bin/bash here; a Web head is built on macOS and Linux.")
        }

        let process = Process()
        process.executableURL = bash
        process.arguments = [script.path] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (process.terminationStatus, String(decoding: output, as: UTF8.self))
    }
}
