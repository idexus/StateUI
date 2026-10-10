// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The code a page shows is the code that runs: `Listings.swift` is written from the regions the sources mark,
/// and never by hand.
@MainActor
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

    /// Every example the sources declare shows code - the listing of its own name, or the listings its `code`
    /// joins - and every listing a sample names is marked.
    func testEveryExampleShowsItsCode() throws {
        let listings = try ListingRegions.all().listings
        var silent: [String] = []
        var unmarked: [String] = []

        for file in try GallerySources.files(under: "Sources", extensions: ["swift"]) {
            let shown = ListingRegions.names(shownBy: file.text)
            let joins = file.text.contains("static var code: String { Listings.joined(")
            silent += shown.examples.filter { listings[$0] == nil && !joins }
            unmarked += shown.named.filter { listings[$0] == nil }
        }

        XCTAssertEqual(silent, [], "examples whose code no region marks")
        XCTAssertEqual(unmarked, [], "listings named in the sources that no region marks")
    }

    /// Every view's body a file of examples declares stands in a listing: a region around its states alone shows
    /// a page none of what it does.
    func testEveryExamplesBodyIsShown() throws {
        var unshown: [String] = []

        for file in try GallerySources.files(under: "Sources", extensions: ["swift"])
        where !ListingRegions.names(shownBy: file.text).examples.isEmpty {
            var inRegion = false
            for (number, line) in file.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let marker = line.trimmingCharacters(in: .whitespaces)
                if marker.hasPrefix("// listing: "), !marker.hasSuffix("// listing: keep") {
                    inRegion = marker != "// listing: end"
                } else if !inRegion, marker.hasPrefix("var body: some View") {
                    unshown.append("\(file.path):\(number + 1)")
                }
            }
        }

        XCTAssertEqual(unshown, [], "bodies of views no listing shows")
    }

    /// The listings as the Swift file every host compiles, in the order of their names: a host's own code - cut
    /// from `Platforms/` - under the condition every host's build defines, which the samples showing it stand under.
    static func file(of listings: [String: String]) -> String {
        func entries(_ names: [String]) -> String {
            names.map { name in
                let text = listings[name]!
                var hashes = "#"
                while text.contains("\"\"\"" + hashes) { hashes += "#" }
                let indented = text.split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.isEmpty ? "" : "        " + $0 }
                    .joined(separator: "\n")
                return "        \"\(name)\": \(hashes)\"\"\"\n\(indented)\n        \"\"\"\(hashes),\n"
            }.joined()
        }
        let names = listings.keys.sorted()
        let ofHosts = names.filter { listings[$0]!.hasPrefix("// Platforms/") }
        let shared = names.filter { !ofHosts.contains($0) }
        return """
            // The code each example shows, by name - written by SampleListingsTests from the regions the
            // sources mark `// listing: <name>`. Change the marked code, never this file.

            /// The code each example shows, by the name its region is marked with.
            enum Listings {
                /// Every listing, by name: the code every host runs, and a host's own where a host's build shows it.
                static let all: [String: String] = shared.merging(ofHosts) { shared, _ in shared }

                /// The code every host runs, by name.
                private static let shared: [String: String] = [

            """ + entries(shared) + """
                ]
            }

            #if APPKIT || UIKIT || GTK || WINUI || ANDROID || WEB
            extension Listings {
                /// The hosts' own code, which only a host's build shows.
                fileprivate static let ofHosts: [String: String] = [

            """ + entries(ofHosts) + """
                ]
            }
            #else
            extension Listings {
                /// No host's code: a build for none shows none.
                fileprivate static let ofHosts: [String: String] = [:]
            }
            #endif

            """
    }
}
