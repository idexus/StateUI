// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import XCTest

final class AppKitDisplayCycleTests: XCTestCase {
    /// A frame's order lives in one place: only the display cycle steps the
    /// walker and runs the core's cycle, so no path of the host walks a trip
    /// or drains a cycle in an order of its own.
    func testOnlyTheDisplayCycleStepsTheWalkerAndRunsTheCoresCycle() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .appendingPathComponent("Sources")
        let steps = ["walker.step(", "core.cycle("]
        var found: [String] = []

        let names = try FileManager.default.contentsOfDirectory(atPath: sources.path).sorted()
        for name in names where name.hasSuffix(".swift") && name != "AppKitDisplayCycle.swift" {
            let text = try String(contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

            for (number, line) in lines.enumerated()
            where !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                for step in steps where line.contains(step) {
                    found.append("\(name):\(number + 1): \(step)")
                }
            }
        }

        XCTAssertEqual(found, [], "a frame is AppKitDisplayCycle's, in its one order")
    }
}
#endif
