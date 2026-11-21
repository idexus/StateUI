// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Numbers drawn from a seed, the same every run.
private struct Draw {
    var state: UInt64

    /// The next number below `bound`.
    mutating func next(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}

/// A run of the board drawn from a seed - destinations written and written again, a movement stopped, the hand's
/// press, moves, lift and loss, a view removed and written again alone and under a change, another room, less
/// motion, the window closed, time moved by uneven lengths - is the same step for step every time, and the rules of
/// a step hold after each.
/// Design: docs/design/host/benchmarks.md#a-generated-run
@MainActor
final class GeneratedSequenceTests: XCTestCase {
    private static let steps = 240

    /// THE SAME SEED IS THE SAME RUN: three seeds, each run twice, the same trace - what was done, where the line
    /// and every view of the scope stand, what the runtime holds, how each change ended - and every kind of step
    /// drawn.
    func testAGeneratedRunIsTheSameEveryTime() throws {
        var drawn: Set<String> = []
        for seed: UInt64 in [1, 20_261_121, 0xC0FFEE] {
            let first = try run(seed: seed)
            let second = try run(seed: seed)

            XCTAssertEqual(first.count, Self.steps)
            for (step, lines) in zip(first, second).enumerated() where lines.0 != lines.1 {
                return XCTFail("seed \(seed) ran two ways at step \(step): \(lines.0) / \(lines.1)")
            }
            drawn.formUnion(first.compactMap { $0.split(separator: " ").first.map(String.init) })
        }
        XCTAssertEqual(
            drawn.sorted(),
            ["advance", "cancel", "change", "close", "drag", "less", "lift", "press", "room", "stop", "turn", "write"])
    }

    /// One run of `steps` steps drawn from `seed`: what each did and how the board stood after it, the rules of
    /// every step held on the way.
    private func run(seed: UInt64) throws -> [String] {
        var draw = Draw(state: seed)
        let bench = BoardBench()
        let (shown, shift) = (bench.shown, bench.shift)
        var (trace, pressed) = ([String](), false)
        var changes: [PresentationChange] = []
        var answers: [Int: PresentationResult] = [:]

        for _ in 0..<Self.steps {
            let written = (shown.wrappedValue, shift.wrappedValue)
            var did: String
            switch draw.next(14) {
            case 0, 1:
                shift.wrappedValue = [0, 60, 150, 300][draw.next(4)]
                did = "write \(shift.wrappedValue)"
            case 2:
                shift.projectedValue.journey.stop()
                did = "stop"
            case 3 where !pressed && bench.line != nil:
                bench.hand(.began)
                pressed = true
                did = "press"
            case 4 where pressed:
                let moved = Double(draw.next(160) - 60)
                bench.hand(.changed, moved: Point(x: moved, y: 0))
                did = "drag \(moved)"
            case 5 where pressed:
                let speed = Double(draw.next(900) - 300)
                bench.hand(.ended, velocity: Point(x: speed, y: 0))
                pressed = false
                did = "lift \(speed)"
            case 6 where pressed:
                bench.hand(.cancelled)
                pressed = false
                did = "cancel"
            case 7:
                shown.wrappedValue.toggle()
                did = "turn"
            case 8 where bench.line != nil:
                changes.append(try bench.scope.presentationChange { shown.wrappedValue.toggle() })
                did = "change"
            case 9:
                let width = Double(200 + 40 * draw.next(6))
                bench.room(width)
                did = "room \(width)"
            case 10:
                bench.reducesMotion.toggle()
                did = "less \(bench.reducesMotion)"
            case 11 where draw.next(3) == 0:
                bench.close()
                try rules(of: bench, after: "close", closed: true)
                pressed = false
                bench.open()
                did = "close"
            default:
                let length = Double(1 + draw.next(90))
                bench.step(length)
                did = "advance \(length)"
                XCTAssertEqual(shown.wrappedValue, written.0, "a frame writes no state")
                XCTAssertEqual(shift.wrappedValue, written.1, "a frame writes no state")
            }
            bench.step(0)

            try rules(of: bench, after: did)
            for (index, change) in changes.enumerated() {
                guard let answered = change.answered.settled else { continue }
                XCTAssertEqual(answers[index] ?? answered, answered, "a change is answered once")
                answers[index] = answered
            }
            trace.append("\(did) -> \(Self.standing(bench)) answered \(answers.sorted { $0.key < $1.key }.map(\.value))")
        }

        if pressed { bench.hand(.cancelled) }
        bench.reducesMotion = false
        bench.rest()
        let rested = try XCTUnwrap(bench.runtime?.holdings)
        XCTAssertEqual(
            [rested.leaving, rested.animations, rested.motions, rested.changes, rested.hands], [0, 0, 0, 0, 0],
            "at rest nothing is held: \(rested)")
        XCTAssertFalse(rested.holdsClock)
        XCTAssertEqual(changes.filter { $0.answered.settled == nil }.count, 0, "every change was answered")
        bench.runtime?.ending()
        bench.runtime = nil
        XCTAssertEqual(bench.halves, 0, "a runtime let go keeps no half")
        return trace
    }

    /// What holds after every step: every number shown is one; a view that leaves is deaf, out of its holder's
    /// children, of what assistive technology meets and of every hand, and within the budget; with less motion
    /// nothing travels and nothing is kept leaving; and a window closed leaves nothing moving.
    private func rules(of bench: BoardBench, after did: String, closed: Bool = false) throws {
        let runtime = try XCTUnwrap(bench.runtime)
        let held = runtime.holdings
        XCTAssertLessThanOrEqual(held.leaving, KeptExits.rootLimit, did)
        if bench.reducesMotion || closed {
            XCTAssertEqual([held.leaving, held.animations], [0, 0], "\(did): \(held)")
        }
        if closed { XCTAssertEqual([held.changes, held.hands], [0, 0], "\(did): \(held)") }
        guard let holder = bench.holder else { return }

        for view in holder.presentedChildren {
            for property in [Prop.opacity, .translationX, .translationY, .scaleX, .scaleY] {
                let number = runtime.tree.presentedPropertyValue(mount: view.mount, property: property)?.number
                XCTAssertTrue(number?.isFinite ?? true, "\(did): \(property) of \(view.type.name) is no number")
            }
            guard view.lifecycle == .exiting else { continue }
            XCTAssertEqual((view.native as? NoView)?.deactivated, 1, "\(did): a view that leaves is deaf, told once")
            XCTAssertFalse(holder.children.contains { $0 === view }, "\(did): and is no child of its holder")
            XCTAssertFalse(runtime.interactions.holds(view), "\(did): no hand holds it")
            XCTAssertTrue(view.ignoresInput, "\(did): it ignores input")
            XCTAssertEqual(view.accessibilityWords.presence, .hiddenWithContents, "\(did): and is met no more")
        }
    }

    /// Where the board stands: the line's state and its journey, every view the scope draws with how it is drawn,
    /// and what the runtime holds.
    private static func standing(_ bench: BoardBench) -> String {
        guard let runtime = bench.runtime else { return "no runtime" }

        var words = ["shown \(bench.shown.wrappedValue) shift \(bench.shift.wrappedValue)"]
        if let line = bench.line, let state = line.driven[.translationX]?.state,
           let journey = runtime.stateChannels.standing(state) {
            words.append("line \(journey.value) to \(journey.destination) at \(journey.velocity)")
        }
        for view in bench.holder?.presentedChildren ?? [] {
            let shown = [Prop.opacity, .translationX, .translationY, .scaleX, .scaleY].map { property in
                runtime.tree.presentedPropertyValue(mount: view.mount, property: property)?.number.map { "\($0)" }
                    ?? "-"
            }
            words.append("\(view.value(.text)?.string ?? view.type.name) \(view.lifecycle) \(shown.joined(separator: ","))")
        }
        words.append("row \(bench.dealt)")
        words.append("\(runtime.holdings)")
        return words.joined(separator: "; ")
    }
}
