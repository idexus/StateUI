// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A wait asks its condition once a step and stops as it holds. This guard reads every Swift source of the
// repository for a loop that repeats under a `where` clause.
// Design: docs/design/host/conformance.md#a-session

import Foundation
import XCTest

final class WaitTests: XCTestCase {
    /// `for _ in 0..<n where waiting { step() }` skips its step once the wait holds but goes on asking `waiting`
    /// to the bound: a wait whose question acts - runs the main loop, asks a browser - takes its whole bound.
    func testEveryWaitStopsAsItHolds() throws {
        var offenders: [String] = []
        for tree in ["lib", "apps"] {
            let root = SourceTree.repository.appendingPathComponent(tree)
            let entered = { SourceTree.entersSources($0) && SourceTree.name(of: $0) != "node_modules" }
            for path in try SourceTree.files(under: root, entering: entered) where path.hasSuffix(".swift") {
                let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
                for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    let code = line.trimmingCharacters(in: .whitespaces)
                    if !code.hasPrefix("//"), code.range(of: #"\bfor _ in .+ where "#, options: .regularExpression) != nil {
                        offenders.append("\(tree)/\(path):\(index + 1) \(code)")
                    }
                }
            }
        }

        XCTAssertEqual(offenders, [], "write `for _ in 0..<n { guard waiting else { break }; step() }`")
    }
}
