// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// A gate is written only where a handler awaits: a step goes down to its storage by step roads, never through a
/// gated twin with `policy: .runConcurrently`.
/// Design: docs/design/core/runs.md#a-step
@MainActor
final class GateSourceTests: XCTestCase {
    /// No source of the library, a host or an application writes `policy: .runConcurrently` before a body with no `await`.
    func testAGateStandsOnlyWhereItsBodyAwaits() throws {
        var found: [String] = []

        for (path, text) in try Self.sources() {
            found += Self.gatesWithNoAwait(in: text).map { "\(path):\($0)" }
        }

        XCTAssertEqual(found, [], "a step is kept with no gate - Handler(step:), ValueHandler(step:), a step overload")
    }

    /// The reading finds a step forwarded through a gate - the policy first or after the event's arguments - and leaves
    /// a body that awaits, and a shared gate made, alone.
    func testTheReadingFindsAStepForwardedThroughAGate() {
        let forwarded = "func a() {\n    onTapped(.runConcurrently) { try handler() }\n}\n"
        let after = "func a() {\n    onChanged(x, policy: .runConcurrently) { try handler() }\n}\n"
        let awaiting = "func a() {\n    onTapped(.runConcurrently) {\n        try await save()\n    }\n}\n"
        let made = "let uploads = Gate(.runConcurrently)\nfunc a() { try handler() }\n"

        XCTAssertEqual(Self.gatesWithNoAwait(in: forwarded), [2])
        XCTAssertEqual(Self.gatesWithNoAwait(in: after), [2])
        XCTAssertEqual(Self.gatesWithNoAwait(in: awaiting), [])
        XCTAssertEqual(Self.gatesWithNoAwait(in: made), [])
    }

    /// The lines of `text` whose policy `.runConcurrently` - `policy: .runConcurrently`, or `(.runConcurrently)` before
    /// a trailing closure - stands before a body with no `await`: the body from the first brace after it to the brace
    /// that closes it.
    static func gatesWithNoAwait(in text: String) -> [Int] {
        let bytes = Array(text.utf8)
        let labeled = Array("policy: .runConcurrently".utf8)
        let first = Array("(.runConcurrently)".utf8)
        var lines: [Int] = []
        var line = 1
        var index = 0

        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "\n") { line += 1 }

            let length = bytes[index...].starts(with: labeled) ? labeled.count
                : bytes[index...].starts(with: first) && closure(after: index + first.count, in: bytes) ? first.count : 0
            if length > 0 {
                if let body = body(after: index + length, in: bytes),
                   !String(decoding: body, as: UTF8.self).contains("await") {
                    lines.append(line)
                }
                index += length
                continue
            }
            index += 1
        }

        return lines
    }

    /// Whether a trailing closure opens at `start`, past spaces.
    private static func closure(after start: Int, in bytes: [UInt8]) -> Bool {
        bytes[start...].first { $0 != UInt8(ascii: " ") } == UInt8(ascii: "{")
    }

    /// The braced body that opens first at or after `start`, braces inside it matched.
    private static func body(after start: Int, in bytes: [UInt8]) -> ArraySlice<UInt8>? {
        guard let open = bytes[start...].firstIndex(of: UInt8(ascii: "{")) else { return nil }

        var depth = 0
        for index in open..<bytes.count {
            if bytes[index] == UInt8(ascii: "{") { depth += 1 }
            if bytes[index] == UInt8(ascii: "}") { depth -= 1 }
            if depth == 0 { return bytes[open...index] }
        }

        return nil
    }

    /// The Swift sources of the library, the hosts and the applications.
    private static func sources() throws -> [(path: String, text: String)] {
        var found = try SourceTree.allSources()
        found += try SourceTree.runtimeSources().filter { !$0.path.hasPrefix("StateUI.Host/") }

        for application in try SourceTree.applications() {
            for name in SourceTree.files(under: application) where name.hasSuffix(".swift") {
                let text = try String(contentsOf: application.appendingPathComponent(name), encoding: .utf8)
                found.append((path: application.lastPathComponent + "/" + name, text: text))
            }
        }

        return found
    }
}
