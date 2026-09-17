// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import XCTest

final class AppKitCoreLinkTests: XCTestCase {
    /// Every call into the running core crosses `AppKitCoreLink`. No other
    /// file of the host calls `StateUIHost`, except for the lane codecs, which
    /// are arithmetic on values the host already holds.
    func testOnlyTheCoreLinkCallsIntoTheCore() throws {
        let codecs = ["journey(from:", "value(of:", "placements(from:"]
        var calls: [String] = []

        for (name, text) in try AppKitSources.all() where name != "AppKitCoreLink.swift" {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

            for (number, line) in lines.enumerated()
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                var rest = Substring(line)
                while let found = rest.range(of: "StateUIHost.") {
                    rest = rest[found.upperBound...]
                    if !codecs.contains(where: rest.hasPrefix) {
                        calls.append("\(name):\(number + 1)")
                    }
                }
            }
        }

        XCTAssertEqual(calls, [], "the host calls into the core only through AppKitCoreLink")
    }
}
#endif
