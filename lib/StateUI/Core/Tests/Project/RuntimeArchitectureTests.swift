// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest

    /// GTK's local zone is read in one place, as it stands: GLib keeps its own from its first reading, so the
    /// locale, the clock and a local offset would part after the user changes the zone.
    /// Design: docs/design/platforms/gtk/runtime.md#the-environment
    func testGTKReadsItsLocalZoneInOnePlace() throws {
        var read = 0
        for (path, text) in try SourceTree.runtimeSources() where path.contains("StateUI.GTK/") {
            read += 1
            XCTAssertFalse(text.contains("g_date_time_new_now_local"), "\(path) reads GLib's kept local zone")
            if !path.hasSuffix("/GTKEnvironment+Machine.swift") {
                XCTAssertFalse(text.contains("g_time_zone_new_local"), "\(path) reads a local zone of its own")
            }
        }
        XCTAssertGreaterThan(read, 10, "the scan read almost nothing of GTK's sources")
    }

/// Every Swift runtime keeps one architecture: the host layer holds
/// the elements every toolkit shares, each host holds only what its toolkit
/// makes it write, and no host does again what an element of the layer does.
/// These guards read the layer and every Swift host's sources as text.
@MainActor
final class RuntimeArchitectureTests: XCTestCase {
    /// One animator animates every value: no other file of a runtime samples a
    /// motion law, so a state channel and a described property cannot animate
    /// the same kind of value two ways.
    func testOnlyTheAnimatorSamplesALaw() throws {
        var found: [String] = []

        for (path, text) in try SourceTree.runtimeSources() where !path.hasSuffix("/Animator.swift") {
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

        for (path, text) in try SourceTree.runtimeSources() where !path.hasSuffix("/DisplayCycle.swift") {
            for (number, line) in code(text) {
                for step in ["animator.advance(", "core.cycle("] where line.contains(step) {
                    found.append("\(path):\(number): \(step)")
                }
            }
        }

        XCTAssertEqual(found, [], "a frame is the DisplayCycle's, in its one order")
    }

    /// A turn is the `Pump`'s: only it renders the core and takes the acts, in its one order.
    func testOnlyThePumpRendersAndTakesTheActs() throws {
        var found: [String] = []

        for (path, text) in try SourceTree.runtimeSources() where !path.hasSuffix("/Pump.swift") {
            for (number, line) in code(text) {
                for step in ["core.render(", "core.takeActCalls("] where line.contains(step) {
                    found.append("\(path):\(number): \(step)")
                }
            }
        }

        XCTAssertEqual(found, [], "a turn is the Pump's, in its one order")
    }

    /// Every call into the running core crosses `CoreLink`. No other file of a
    /// runtime calls `HostBoundary`, except for the lane codecs, which are
    /// arithmetic on values the runtime already holds.
    func testOnlyTheCoreLinkCallsIntoTheCore() throws {
        let codecs = ["journey(from:", "value(of:", "placements(from:"]
        var calls: [String] = []

        for (path, text) in try SourceTree.runtimeSources() where !path.hasSuffix("/CoreLink.swift") {
            for (number, line) in code(text) {
                var rest = Substring(line)
                while let found = rest.range(of: "HostBoundary.") {
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

        for (path, text) in try SourceTree.runtimeSources() {
            for match in flag.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                found.append("\(path): \(text[range])")
            }
        }

        XCTAssertEqual(found, [], "a program's write is marked by ProgramWrite alone")
    }

    /// A value in a range is held there by the host layer's arithmetic alone: no stepper, slider, grid or list of a
    /// host holds a number between two ends by its own `min(max(...))`, so every host clamps alike.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    func testOnlyTheHostLayerHoldsAValueInItsRange() throws {
        let ranged = try NSRegularExpression(pattern: #"(Stepper|Slider|Grid|Items)View\.swift$"#)
        let found = try SourceTree.runtimeSources()
            .filter { !$0.path.hasPrefix("StateUI.Host/") }
            .filter { ranged.firstMatch(in: $0.path, range: NSRange($0.path.startIndex..., in: $0.path)) != nil }
            .filter { $0.text.contains("min(max(") }
            .map(\.path)

        XCTAssertEqual(found, [], "ValueArithmetic.clamped holds a value in its range")
    }

    /// The ends of a range the tree gives none, and a step it gives none, are the host layer's alone: no host's
    /// source fills in a slider's or a stepper's end or step of its own, so every host stands a control alike.
    /// Design: docs/design/host/runtime.md#a-value-in-a-range
    func testOnlyTheHostLayerFillsInARangesEnds() throws {
        let filled = try NSRegularExpression(
            pattern: #"(RangeElementContract\.(minimum|maximum)|StepperContract\.step)(\]|\.token\))\s*\?\?"#)
        let found = try SourceTree.runtimeSources()
            .filter { !$0.path.hasPrefix("StateUI.Host/") }
            .filter { filled.firstMatch(in: $0.text, range: NSRange($0.text.startIndex..., in: $0.text)) != nil }
            .map(\.path)

        XCTAssertEqual(found, [], "ValueArithmetic.ends and .step fill in what the tree leaves out")
    }

    /// A scroller rests on the frame clock's time alone: no timer and no second clock in any runtime's scrolling
    /// decides when a movement is over, so a hand-wound clock reproduces every rest.
    func testAScrollersRestIsTimedByTheFrameClockAlone() throws {
        let timers = ["asyncAfter(", "DispatchWorkItem", "Timer.", "scheduledTimer", "afterDelay:", "postDelayed"]
        let scrolling = try SourceTree.runtimeSources().filter { $0.path.contains("Scroll") }
        var found: [String] = []

        for (path, text) in scrolling {
            for (number, line) in code(text) {
                for timer in timers where line.contains(timer) {
                    found.append("\(path):\(number): \(timer)")
                }
            }
        }

        XCTAssertTrue(scrolling.contains { $0.path.hasSuffix("ScrollMovement.swift") }, "the movement is read")
        XCTAssertEqual(found, [], "a scroller rests on the frame clock's time")
    }

    /// The runtimes' types keep the architecture's reserved words: no type of
    /// a runtime is an ENGINE - that word is the application's frame code -
    /// and a CHANNEL is only the state channel, one per `@State`.
    func testTheRuntimesTypesKeepTheReservedWords() throws {
        let declaration = try NSRegularExpression(
            pattern: #"\b(?:class|struct|enum|protocol|actor|typealias)\s+(\w+)"#)
        var found: [String] = []

        for (path, text) in try SourceTree.runtimeSources() {
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
