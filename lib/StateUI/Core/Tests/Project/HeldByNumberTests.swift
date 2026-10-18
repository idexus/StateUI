// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a host hands across C, Java or JavaScript by number is held in the host layer's tables, numbered by the
// process's one count. These guards read every Swift runtime's sources and every backend's for a count or a table
// by number of a host's own.
// Design: docs/design/host/tree.md#held-by-number

import Foundation
import XCTest

final class HeldByNumberTests: XCTestCase {
    /// A number a host hands out is the process's one count's (`HostNumbers`): a count of a host's own gives a
    /// number another table may hold.
    func testEveryNumberAHostHandsOutIsTheOneCounts() throws {
        try XCTAssertEqual(
            Self.offenders(#"static var \w+: Int(32|64)? = [01]\b"#, allowed: Self.counting), [],
            "take the number from `Numbered.reserve()`, `LiveViews.reserve()` or `HostNumbers.next()`")
    }

    /// What a host holds by a number it handed out stands in `Numbered` or `LiveViews`, which take out and let go
    /// alike everywhere and which a test counts.
    func testWhatAHostHoldsByNumberStandsInTheSharedTables() throws {
        try XCTAssertEqual(
            Self.offenders(#"\[Int64: "#, allowed: Self.keyedByNumber), [],
            "hold it in a `Numbered` (or a view weakly in `LiveViews`)")
    }

    /// Each file a match is allowed in, with why; the matches anywhere else, and a file listed that holds none.
    private static func offenders(_ pattern: String, allowed: [String: String]) throws -> [String] {
        var offenders: [String] = []
        var matched: Set<String> = []
        let sources = try SourceTree.runtimeSources()
            + SourceTree.backendSources().filter { !$0.path.contains("/Tests/") }

        for source in sources {
            let file = (source.path as NSString).lastPathComponent
            for (index, line) in source.text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.trimmingCharacters(in: .whitespaces)
                guard !code.hasPrefix("//"), code.range(of: pattern, options: .regularExpression) != nil else {
                    continue
                }
                matched.insert(file)
                if allowed[file] == nil { offenders.append("\(source.path):\(index + 1) \(code)") }
            }
        }

        let stale = allowed.keys.filter { !matched.contains($0) }.sorted().map { "\($0) is listed and holds none" }
        return offenders.sorted() + stale
    }

    private static let counting: [String: String] = [
        "HostNumbers.swift": "the process's one count",
        "WebRelay.swift": "the JavaScript relay's listeners, by its own 32-bit numbers - a 64-bit one is a BigInt there",
    ]

    private static let keyedByNumber: [String: String] = [
        "Numbered.swift": "the table itself",
        "FrameFollowers.swift": "views ordered by the numbers they were made under, not numbers it hands out",
        "GTKWindow.swift": "each window's last frame told, by the window's number",
    ]
}
