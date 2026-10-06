// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// A sample's code is the code beside it: what the page shows under its heading compiles as a reader would
/// paste it, against the library and the Gallery's own helpers.
final class SampleCodeTests: XCTestCase {
    /// Every sample's code compiles - every sample the sources hold, whichever host it is shown on.
    func testEverySamplesCodeCompiles() throws {
        guard let module = DocumentationExamplesTests.builtModuleDirectory() else {
            return XCTFail("no StateUI.swiftmodule beside the test bundle - no sample's code was checked")
        }
        let sdk = try DocumentationExamplesTests.sdkPath()
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-samples-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let listings = try SampleSource.all().flatMap { sample in
            sample.code.enumerated().map { index, code in
                (name: sample.code.count == 1 ? sample.name : "\(sample.name), listing \(index + 1)", code: code)
            }
        }
        XCTAssertFalse(listings.isEmpty, "no sample's code was found")

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
                XCTFail("\(listing.name): its code does not compile as shown:\n\(output)")
            }
        }
    }
}
