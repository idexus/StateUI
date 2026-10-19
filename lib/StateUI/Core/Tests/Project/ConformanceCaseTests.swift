// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// The conformance cases keep the session's rules where a slip compiles: a case sees that nothing happened only
/// after a turn of the pump.
/// Design: docs/design/host/conformance.md#a-session
final class ConformanceCaseTests: XCTestCase {
    /// AN EXPECTATION THAT NOTHING WAS HEARD COMES AFTER A TURN: a wait ends the moment what it waited for came, and a
    /// toolkit's late echo - a spinner telling the program's write back as the user's - lands in the turn after it.
    func testANothingHeardComesAfterATurn() throws {
        let cases = SourceTree.repository.appendingPathComponent("lib/StateUI/StateUI.Conformance/Sources/Contract")
        let nothing = try NSRegularExpression(
            pattern: #"expect\(\w+\.values(\.count)?, (\[\]|0)|expect\(\w+\.values\.isEmpty, true"#)
        let pump = try NSRegularExpression(pattern: #"\bturn\(\)|\.settle\b|perform\(|\.frame\(\)"#)
        var read = 0
        var bare: [String] = []

        for file in try SourceTree.files(under: cases, entering: { _ in true }) where file.hasSuffix(".swift") {
            let lines = try String(contentsOf: cases.appendingPathComponent(file), encoding: .utf8)
                .components(separatedBy: "\n")
            for (number, line) in lines.enumerated() where Self.matches(nothing, line) {
                read += 1
                let before = lines[..<number].last { Self.matches(pump, $0) } ?? ""
                if !before.contains("turn()") { bare.append("\(file):\(number + 1)") }
            }
        }

        XCTAssertGreaterThan(read, 10, "the walk read almost no expectation of nothing heard")
        XCTAssertEqual(bare, [], "nothing heard, expected before a turn: " + bare.joined(separator: ", "))
    }

    /// THE CLOCK WAITS ONLY FOR ANOTHER PROCESS: a web view's page loads in its engine's own, as fast as the machine
    /// lets it; whatever the application's process does, steps wait for, so a verdict is never the machine's speed.
    func testTheClockWaitsOnlyForAnotherProcess() throws {
        let cases = SourceTree.repository.appendingPathComponent("lib/StateUI/StateUI.Conformance/Sources/Contract")
        let anotherProcess: Set<String> = ["WebViewTests.swift"]
        var clocked: [String] = []
        for file in try SourceTree.files(under: cases, entering: { _ in true }) where file.hasSuffix(".swift") {
            let name = (file as NSString).lastPathComponent
            let text = try String(contentsOf: cases.appendingPathComponent(file), encoding: .utf8)
            if text.contains("settle(for:"), !anotherProcess.contains(name) { clocked.append(name) }
        }
        XCTAssertEqual(clocked, [], "a case waits by the clock on its own process")
    }

    private static func matches(_ expression: NSRegularExpression, _ line: String) -> Bool {
        expression.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }
}
