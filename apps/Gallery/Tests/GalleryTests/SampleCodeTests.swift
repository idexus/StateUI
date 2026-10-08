// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@testable import GalleryUI

/// What a sample's page shows under its heading compiles as a reader would paste it, against the library and the
/// Gallery's own helpers: a listing is cut from running code, and a cut that leaves out what it needs is caught.
final class SampleCodeTests: XCTestCase {
    /// Every listing in Swift compiles - every sample's, whichever host it is shown on.
    func testEverySamplesCodeCompiles() throws {
        guard let module = DocumentationExamplesTests.builtModuleDirectory() else {
            return XCTFail("no StateUI.swiftmodule beside the test bundle - no sample's code was checked")
        }
        let sdk = try DocumentationExamplesTests.sdkPath()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-samples-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        // The marked listings in Swift: what an example joins compiles as one, its parts from another file's
        // middle and a host's code (a name with a dot) left out; any other listing on its own.
        let joined = try GallerySources.files(under: "Sources", extensions: ["swift"]).flatMap { file in
            file.text.matches(of: try! Regex(#"Listings\.joined\(([^)]*)\)"#)).map { match in
                String(file.text[match.range]).matches(of: try! Regex(#""([^"]+)""#))
                    .compactMap { $0.output[1].substring.map(String.init) }
                    .filter { !$0.contains(".") }
            }
        }
        let parts = Set(joined.flatMap { $0 })
        let marked = joined.map { names in
            (name: "the listings \(names.joined(separator: " + "))",
             code: names.compactMap { Listings.all[$0] }.joined(separator: "\n\n"))
        }
            + Listings.all.filter { !$0.key.contains(".") && !parts.contains($0.key) }.sorted { $0.key < $1.key }
            .map { (name: "the listing `\($0.key)`", code: $0.value) }
        let listings = marked
        XCTAssertFalse(listings.isEmpty, "no listing was found")

        let files = try listings.enumerated().map { index, listing in
            let file = scratch.appendingPathComponent("listing_\(index).swift")
            try Data(ListingFile.text(of: listing.code).utf8).write(to: file)
            return file
        }
        let outputs = CompilerOutputs(count: files.count)
        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            outputs.set(index, DocumentationExamplesTests.typecheck(files[index], module: module, sdk: sdk))
        }

        for (index, listing) in listings.enumerated() {
            if let output = outputs.value(index) {
                XCTFail("\(listing.name) does not compile as shown:\n\(output)")
            }
        }
    }
}
