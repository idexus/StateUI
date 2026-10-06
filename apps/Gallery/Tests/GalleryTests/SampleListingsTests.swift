// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The code a page shows is the code that runs: `Listings.swift` is written from the regions the sources mark,
/// and never by hand.
final class SampleListingsTests: XCTestCase {
    /// The file the listings are written into, which every host compiles.
    private static let listingsFile = GallerySources.gallery.appendingPathComponent("Sources/Gallery/Listings.swift")

    /// `Listings.swift` holds what the marked code says, and the marks are whole. With `STATEUI_UPDATE_SAMPLES=1`
    /// the test writes it.
    func testTheListingsAreWrittenFromTheCodeTheyShow() throws {
        let read = try ListingRegions.all()
        XCTAssertEqual(read.problems, [], "the listings' marks")
        let written = Self.file(of: read.listings)

        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_SAMPLES"] == "1" {
            return try written.write(to: Self.listingsFile, atomically: true, encoding: .utf8)
        }

        let standing = try String(contentsOf: Self.listingsFile, encoding: .utf8)
            .replacingOccurrences(of: "\r\n", with: "\n")
        XCTAssertTrue(standing == written, """
            Listings.swift is not what the marked code says. Write it again: STATEUI_UPDATE_SAMPLES=1 swift test \
            --package-path apps/Gallery --filter SampleListingsTests
            """)
    }

    /// Every example the sources declare shows code: the listing of its own name, or the listings its `code` joins.
    func testEveryExampleShowsItsCode() throws {
        let listings = try ListingRegions.all().listings
        let example = try! Regex(#"(?m)^(?:private |fileprivate )?struct (\w+)\s*:[^{]*\bExampleContent\b"#)
        var silent: [String] = []

        for file in try GallerySources.files(under: "Sources", extensions: ["swift"]) {
            for match in file.text.matches(of: example) {
                guard let name = match.output[1].substring.map(String.init) else { continue }
                if listings[name] == nil, !file.text.contains("static var code: String { Listings.joined(") {
                    silent.append(name)
                }
            }
        }

        XCTAssertEqual(silent, [], "examples whose code no region marks")

        let named = try! Regex(#"Listings\.joined\(([^)]*)\)|Listings\.all\["([^"]+)"\]|marked: ([^)]*)\)"#)
        var unmarked: [String] = []
        for file in try GallerySources.files(under: "Sources", extensions: ["swift"]) {
            for match in file.text.matches(of: named) {
                let quoted = String(file.text[match.range]).matches(of: try! Regex(#""([^"]+)""#))
                unmarked += quoted.compactMap { $0.output[1].substring.map(String.init) }.filter { listings[$0] == nil }
            }
        }
        XCTAssertEqual(unmarked, [], "listings named in the sources that no region marks")
    }

    /// The listings as the Swift file every host compiles, in the order of their names.
    static func file(of listings: [String: String]) -> String {
        var file = """
            // The code each example shows, by name - written by SampleListingsTests from the regions the
            // sources mark `// listing: <name>`. Change the marked code, never this file.

            /// The code each example shows, by the name its region is marked with.
            enum Listings {
                /// Every listing, by name.
                static let all: [String: String] = [

            """

        for name in listings.keys.sorted() {
            let text = listings[name]!
            var hashes = "#"
            while text.contains("\"\"\"" + hashes) { hashes += "#" }
            let indented = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.isEmpty ? "" : "        " + $0 }
                .joined(separator: "\n")
            file += "        \"\(name)\": \(hashes)\"\"\"\n\(indented)\n        \"\"\"\(hashes),\n"
        }

        return file + "    ]\n}\n"
    }
}
