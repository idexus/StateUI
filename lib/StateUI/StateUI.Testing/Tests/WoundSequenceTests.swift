// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@testable import StateUITesting
import XCTest

/// A generated run of a page on a clock wound by hand - destinations written and written again, a press, its
/// moves, its lift and its being taken away, the view removed and shown again, time advanced by uneven lengths -
/// gives the same presentations step for step every time it runs.
@MainActor
final class WoundSequenceTests: XCTestCase {
    /// Three seeds, each run twice: the same trace, the clock at the sum of its advances, no number that is none.
    func testAGeneratedRunIsTheSameEveryTime() async throws {
        for seed: UInt64 in [1, 20_261_119, 0xC0FFEE] {
            let first = try await run(seed: seed)
            let second = try await run(seed: seed)

            XCTAssertEqual(first, second, "seed \(seed) ran two ways")
            XCTAssertEqual(first.count, Self.steps)
            XCTAssertTrue(first.contains { $0.contains("across") }, "seed \(seed) never read the box")
        }
    }

    private static let steps = 60

    /// One run of `steps` steps drawn from `seed`: what each step did and how the box stood after it.
    private func run(seed: UInt64) async throws -> [String] {
        var draw = Draw(state: seed)
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { BoardPage() }
        var (trace, advanced, pressed) = ([String](), Duration.zero, false)

        for _ in 0..<Self.steps {
            let box = try? window.element("board.box")
            var did: String
            switch draw.next(8) {
            case 0:
                try window.element("board.far").send(.activate)
                did = "far"
            case 1:
                try window.element("board.near").send(.activate)
                did = "near"
            case 2:
                try window.element("board.stop").send(.activate)
                did = "stop"
            case 3 where box != nil && !pressed:
                try box?.send(.pressDown(at: Point(x: 10, y: 10)))
                pressed = true
                did = "press"
            case 4 where box != nil && pressed:
                try box?.send(.drag(to: Point(x: Double(10 + draw.next(120)), y: 10)))
                did = "drag"
            case 5 where box != nil && pressed:
                try box?.send(draw.next(2) == 0 ? .lift : .cancelInteraction)
                pressed = false
                did = "let go"
            case 6 where !pressed:
                try window.element("board.shown").send(.toggle)
                did = "turn"
            default:
                let length = Duration.milliseconds(1 + draw.next(90))
                try await clock.advance(by: length, step: .milliseconds(1 + draw.next(16)))
                advanced += length
                did = "advance \(length)"
            }
            try await window.flush()

            XCTAssertEqual(clock.now, advanced, "the clock stands at what it was advanced by")
            if let stands = try? window.element("board.box").presentation() {
                XCTAssertTrue(stands.translation.x.isFinite && stands.opacity.isFinite)
                did += " across \(stands.translation.x) opacity \(stands.opacity) mounting \(stands.generation)"
            }
            trace.append(did + " said \(try window.element("board.said").value(TextElementContract.text) ?? "")")
        }
        try await window.close()

        // A mounting's number is the process's, never a run's: told apart within a run, counted from its first.
        return Self.counted(trace)
    }

    /// The trace with each mounting's number replaced by its place among the run's mountings, from 1.
    private static func counted(_ trace: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return trace.map { line in
            var words = line.split(separator: " ").map(String.init)
            if let at = words.firstIndex(of: "mounting"), at + 1 < words.count {
                let number = words[at + 1]
                if seen[number] == nil { seen[number] = seen.count + 1 }
                words[at + 1] = "\(seen[number] ?? 0)"
            }
            return words.joined(separator: " ")
        }
    }
}

/// Numbers drawn from a seed, the same every run.
private struct Draw {
    var state: UInt64

    /// The next number below `bound`.
    mutating func next(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}

/// A box two buttons send near and far, a third stops, a pan moves and a switch takes off the page; words say how
/// the last movement ended.
private struct BoardPage: View {
    @State private var across = 0.0
    @State private var fade = 1.0
    @State private var taken = 0.0
    @State private var shown = true
    @State private var said = ""

    var body: some View {
        VStack {
            if shown {
                Rectangle()
                    .translationX($across)
                    .opacity($fade)
                    .onPanUpdated { update in
                        switch update.phase {
                        case .began: taken = $across.journey.sample?.value ?? across
                        case .changed: $across.journey.snap(to: taken + update.total.x)
                        case .ended: $across.journey.move(to: 0, .spring())
                        default: $across.journey.snap(to: taken)
                        }
                    }
                    .id("box")
                    .accessibilityIdentifier("board.box")
            }
            Text(said).accessibilityIdentifier("board.said")
            Button("Far").accessibilityIdentifier("board.far").onClicked(policy: .cancelPrevious) {
                $fade.journey.move(to: 0.2, .eased(.milliseconds(120)))
                said = "\(try await $across.journey.move(to: 300, .eased(.milliseconds(250), curve: .cubicInOut)).result())"
            }
            Button("Near").accessibilityIdentifier("board.near").onClicked(policy: .cancelPrevious) {
                $fade.journey.move(to: 1, .eased(.milliseconds(80), curve: .linear))
                said = "\(try await $across.journey.move(to: 40, .spring()).result())"
            }
            Button("Stop").accessibilityIdentifier("board.stop").onClicked { $across.journey.stop() }
            Switch($shown).accessibilityIdentifier("board.shown")
        }
    }
}
