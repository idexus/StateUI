// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// A sample's notes are read again whenever what they speak of changes. Its listings follow its code by
/// themselves; its notes are prose, so a fingerprint of the sample's file and of every file its listings are
/// cut from stands in `SampleReviews.txt`, recorded once they were read against them.
final class SampleReviewTests: XCTestCase {
    /// Where the fingerprints stand - beside the test target, which reads it as a file rather than a resource.
    private static let reviews = GallerySources.gallery.appendingPathComponent("Tests/SampleReviews.txt")

    /// Every sample was read since its sources last changed: its own file, and every file a listing of it is cut
    /// from.
    func testEverySampleWasReadSinceItsSourcesChanged() throws {
        let marked = try ListingRegions.all().files
        let sources = try GallerySources.files(under: "Sources", extensions: ListingRegions.extensions)
            + GallerySources.files(under: "Platforms", extensions: ListingRegions.extensions)
        let texts = Dictionary(sources.map { ($0.path, $0.text) }) { first, _ in first }

        var samples: [(name: String, files: [String], fingerprint: String)] = []
        for file in sources where file.path.hasPrefix("Sources/Samples/") {
            let shown = ListingRegions.names(shownBy: file.text)
            guard !shown.examples.isEmpty else { continue }

            let read = Set([file.path] + (shown.examples + shown.named).flatMap { marked[$0] ?? [] }).sorted()
            samples.append(((file.path as NSString).lastPathComponent, read, Self.fingerprint(of: read, in: texts)))
        }
        samples.sort { $0.name < $1.name }

        if ProcessInfo.processInfo.environment["STATEUI_UPDATE_SAMPLES"] == "1" {
            let lines = samples.map { "\($0.name) \($0.fingerprint)" }
            return try (Self.heading + lines).joined(separator: "\n").appending("\n")
                .write(to: Self.reviews, atomically: true, encoding: .utf8)
        }

        let recorded = try Self.recorded()
        let unread = samples.filter { recorded[$0.name] != $0.fingerprint }
            .map { "  \($0.name): \($0.files.joined(separator: ", "))" }
        let gone = Set(recorded.keys).subtracting(samples.map(\.name)).sorted().map { "  \($0), gone" }

        XCTAssertTrue(unread.isEmpty && gone.isEmpty, """
            These samples changed since their notes were last read against them:
            \((unread + gone).joined(separator: "\n"))
            Read each one's notes, and the comments inside its listings, against what changed; correct what no \
            longer holds; then record it: STATEUI_UPDATE_SAMPLES=1 swift test --package-path apps/Gallery \
            --filter SampleReviewTests
            """)
    }

    /// What heads the fingerprints' file.
    private static let heading = [
        "# Each sample's sources - its file and every file its listings are cut from - fingerprinted when its",
        "# notes were last read against them. SampleReviewTests compares; only after the reading,",
        "# STATEUI_UPDATE_SAMPLES=1 records.",
    ]

    /// FNV-1a over each file's path and text, in the order of their paths.
    private static func fingerprint(of files: [String], in texts: [String: String]) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325

        for file in files {
            for byte in "\(file)\n\(texts[file] ?? "")\n".utf8 {
                hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
            }
        }

        let digits = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }

    /// The fingerprints recorded, by sample.
    private static func recorded() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: reviews.path) else { return [:] }

        let lines = try String(contentsOf: reviews, encoding: .utf8).split(whereSeparator: \.isNewline)
        return Dictionary(lines.filter { !$0.hasPrefix("#") }.compactMap { line in
            let parts = line.split(separator: " ")
            return parts.count == 2 ? (String(parts[0]), String(parts[1])) : nil
        }) { first, _ in first }
    }
}
