// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

/// Every Swift runtime keeps one architecture: the core's host layer holds
/// the elements every toolkit shares, each host holds only what its toolkit
/// makes it write, and no host does again what an element of the layer does.
/// These guards read the layer and every Swift host's sources as text.
final class RuntimeArchitectureTests: XCTestCase {
    /// One animator animates every value: no other file of a runtime samples a
    /// motion law, so a state channel and a described property cannot animate
    /// the same kind of value two ways.
    func testOnlyTheAnimatorSamplesALaw() throws {
        var found: [String] = []

        for (path, text) in try Fixtures.runtimeSources() where !path.hasSuffix("/Animator.swift") {
            for (number, line) in code(text) where line.contains("HostMotionLaw.sample(") {
                found.append("\(path):\(number)")
            }
        }

        XCTAssertEqual(found, [], "a value is animated by the Animator alone")
    }

    /// A frame's order lives in one place: only the display cycle advances the animator and runs the
    /// core's cycle, so no path of a runtime animates or drains a cycle in an order of its own.
    func testOnlyTheDisplayCycleAdvancesTheAnimatorAndRunsTheCoresCycle() throws {
        var found: [String] = []

        for (path, text) in try Fixtures.runtimeSources() where !path.hasSuffix("/DisplayCycle.swift") {
            for (number, line) in code(text) {
                for step in ["animator.advance(", "core.cycle("] where line.contains(step) {
                    found.append("\(path):\(number): \(step)")
                }
            }
        }

        XCTAssertEqual(found, [], "a frame is the DisplayCycle's, in its one order")
    }

    /// Every call into the running core crosses `CoreLink`. No other file of a
    /// runtime calls `StateUIHost`, except for the lane codecs, which are
    /// arithmetic on values the runtime already holds.
    func testOnlyTheCoreLinkCallsIntoTheCore() throws {
        let codecs = ["journey(from:", "value(of:", "placements(from:"]
        var calls: [String] = []

        for (path, text) in try Fixtures.runtimeSources() where !path.hasSuffix("/CoreLink.swift") {
            for (number, line) in code(text) {
                var rest = Substring(line)
                while let found = rest.range(of: "StateUIHost.") {
                    rest = rest[found.upperBound...]
                    if !codecs.contains(where: rest.hasPrefix) {
                        calls.append("\(path):\(number)")
                    }
                }
            }
        }

        XCTAssertEqual(calls, [], "a runtime calls into the core only through CoreLink")
    }

    /// One mark says a native control is being written by the program: no
    /// control keeps a flag of its own, so an application write cannot echo
    /// back as a user's report through a control that forgot to raise one.
    func testNoControlKeepsAWriteFlagOfItsOwn() throws {
        let flag = try NSRegularExpression(pattern: #"\bvar\s+(applying\w*)\b"#)
        var found: [String] = []

        for (path, text) in try Fixtures.runtimeSources() {
            for match in flag.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                found.append("\(path): \(text[range])")
            }
        }

        XCTAssertEqual(found, [], "a program's write is marked by ProgramWrite alone")
    }

    /// The runtimes' types keep the architecture's reserved words: no type of
    /// a runtime is an ENGINE - that word is the application's frame code -
    /// and a CHANNEL is only the state channel, one per `@State`.
    func testTheRuntimesTypesKeepTheReservedWords() throws {
        let declaration = try NSRegularExpression(
            pattern: #"\b(?:class|struct|enum|protocol|actor|typealias)\s+(\w+)"#)
        var found: [String] = []

        for (path, text) in try Fixtures.runtimeSources() {
            let matches = declaration.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in matches {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let type = String(text[range])
                if type.hasSuffix("Engine")
                    || (type.contains("Channel") && !type.hasPrefix("StateChannel")) {
                    found.append("\(path): \(type)")
                }
            }
        }

        XCTAssertEqual(found, [], "an engine is application code, and a channel is a state's")
    }

    /// The lines of `text` that are code, not a comment, numbered from one.
    private func code(_ text: String) -> [(number: Int, line: Substring)] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { ($0.offset + 1, $0.element) }
    }
}
