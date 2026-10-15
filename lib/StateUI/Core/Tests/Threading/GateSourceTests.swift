// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// A gate is written only where a handler awaits: a step goes down to its storage by step roads, never through a
/// gated twin with `gate: .none`.
/// Design: docs/design/core/runs.md#a-step
@MainActor
final class GateSourceTests: XCTestCase {
    /// No source of the library, a host or an application writes `gate: .none` before a body with no `await`.
    func testAGateStandsOnlyWhereItsBodyAwaits() throws {
        var found: [String] = []

        for (path, text) in try Self.sources() {
            found += Self.gatesWithNoAwait(in: text).map { "\(path):\($0)" }
        }

        XCTAssertEqual(found, [], "a step is kept with no gate - Handler(step:), ValueHandler(step:), a step overload")
    }

    /// The reading finds a step forwarded through a gate, and leaves a body that awaits alone.
    func testTheReadingFindsAStepForwardedThroughAGate() {
        let forwarded = "func a() {\n    onTapped(gate: .none) { try handler() }\n}\n"
        let awaiting = "func a() {\n    onTapped(gate: .none) {\n        try await save()\n    }\n}\n"

        XCTAssertEqual(Self.gatesWithNoAwait(in: forwarded), [2])
        XCTAssertEqual(Self.gatesWithNoAwait(in: awaiting), [])
    }

    /// The lines of `text` whose `gate: .none` stands before a body with no `await` - the body from the first brace
    /// after it to the brace that closes it.
    static func gatesWithNoAwait(in text: String) -> [Int] {
        let bytes = Array(text.utf8)
        let gate = Array("gate: .none".utf8)
        var lines: [Int] = []
        var line = 1
        var index = 0

        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "\n") { line += 1 }

            if bytes[index...].starts(with: gate) {
                if let body = body(after: index + gate.count, in: bytes),
                   !String(decoding: body, as: UTF8.self).contains("await") {
                    lines.append(line)
                }
                index += gate.count
                continue
            }
            index += 1
        }

        return lines
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
