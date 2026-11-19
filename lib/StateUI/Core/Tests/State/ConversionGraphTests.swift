// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The conversions' graph: a derived state's DESTINATION is worked out from its sources' destinations - never from
// where a source stands on a frame - once a change, sources first; and a write into a derived state goes back to
// its sources whole or not at all.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class ConversionGraphTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    private var board: CycleBoard { Renderer.shared.board }

    /// A DIAMOND MEETS ONCE: two branches of one source reach their common result in one pass, both moved - the
    /// result is never worked out from one new branch and one old.
    func testADiamondMeetsOnceWithBothBranchesMoved() {
        let source = State(wrappedValue: 1.0)
        var seen: [(Double, Double)] = []
        let doubled = source.projectedValue.convert { $0 * 2 }
        let tripled = source.projectedValue.convert { $0 * 3 }
        let sum = Binding<Double>.multi(doubled, tripled).convert { two, three -> Double in
            seen.append((two, three))
            return two + three
        }
        let renders = Renders()
        renders.render(Slider(sum).maximum(100).node)
        seen.removeAll()

        source.wrappedValue = 2
        XCTAssertTrue(board.asked, "a destination written is work for the graph")
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(seen.count, 1, "worked out once")
        XCTAssertEqual(seen.first?.0, 4)
        XCTAssertEqual(seen.first?.1, 6, "from both branches moved")
        XCTAssertEqual(sum.wrappedValue, 10)
        XCTAssertFalse(board.conversions.isStale)
        _ = renders
    }

    /// AN EQUAL RESULT IS NOTHING: a source moved to where the arithmetic answers the same publishes no
    /// destination - no revision, nothing sent to the host.
    func testAnEqualResultPublishesNothing() throws {
        let source = State(wrappedValue: 0.2)
        let whole = source.projectedValue.convert { ($0 * 10).rounded() }
        let renders = Renders()
        renders.render(Slider(whole).maximum(10).node)
        board.cycle(now: 0, reducesMotion: false)
        _ = board.dirty()
        let revision = whole.storage.targetRevision

        source.wrappedValue = 0.21
        board.cycle(now: 16, reducesMotion: false)

        XCTAssertEqual(whole.storage.targetRevision, revision, "2 again: no destination moved")
        XCTAssertTrue(board.dirty().isEmpty, "and the host is told nothing")
        _ = renders
    }

    /// A SOURCE'S FRAMES RUN NO CONVERSION: the host walking the source says where it stands every frame, and the
    /// arithmetic is not asked once - it was worked out from where the source is going.
    func testASourcesFramesRunNoConversion() throws {
        let source = State(wrappedValue: 0.0)
        var worked = 0
        let shown = source.projectedValue.convert { value -> Double in
            worked += 1
            return value * 100
        }
        let renders = Renders()
        renders.render(VStack {
            Rectangle().opacity(source.projectedValue)
            Slider(shown).maximum(100)
        }.node)
        source.wrappedValue = 1
        board.cycle(now: 0, reducesMotion: false)
        let before = worked

        for frame in 1...10 {
            moved(source.number, to: [Double(frame) / 10, 1, 1, 0, 0, 0, 0, 0], mask: 0b101)
            board.cycle(now: Double(frame) * 16, reducesMotion: false)
        }

        XCTAssertEqual(worked, before, "ten frames of the source asked the arithmetic")
        XCTAssertEqual(shown.wrappedValue, 100, "the result stands where the source is going")
        _ = renders
    }

    /// THE RESULT TRAVELS BY ITS OWN MOTION: what it is given, whatever its sources travel under; and showing it
    /// opens no channel for a source.
    func testTheResultHasItsOwnMotionAndItsSourcesNoChannel() throws {
        let width = State(wrappedValue: 100.0, motion: .eased(.seconds(2)))
        let height = State(wrappedValue: 50.0, motion: .glide(longest: .milliseconds(300)))
        let area = Binding<Double>.multi(width.projectedValue, height.projectedValue)
            .convert({ min($0 * $1 / 40_000, 1) }, motion: .spring())
        let renders = Renders()
        renders.render(Rectangle().opacity(area).node)

        XCTAssertEqual(area.journey.motion, .spring())
        XCTAssertFalse(width.storage.carried, "a source is plain data")
        XCTAssertFalse(height.storage.carried)

        let image = try XCTUnwrap(area.storage.image)
        XCTAssertTrue(image.hasChannel, "the result is what the host shows")
        let (_, handed) = try XCTUnwrap(HostAnimatorReport.standing(Renderer.shared.number(for: image)))
        XCTAssertEqual(handed.motion, .spring(), "and it is handed the result's own motion")
        _ = renders
    }

    /// THE WAY BACK RUNS FOR A WRITE INTO THE RESULT ALONE. A source at 0.123 shown in hundredths stays 0.123
    /// through every frame of the result's own animation; the user's report of 40 lands 0.4.
    func testFramesOfTheResultNeverGoBackAndAReportDoes() throws {
        let source = State(wrappedValue: 0.123)
        let percent = source.projectedValue.convert({ ($0 * 100).rounded() }, back: { $0 / 100 })
        let renders = Renders()
        renders.render(Slider(percent).maximum(100).node)
        board.cycle(now: 0, reducesMotion: false)
        let number = Renderer.shared.number(for: try XCTUnwrap(percent.storage.image))
        XCTAssertEqual(percent.wrappedValue, 12)

        for frame in 1...8 {
            moved(number, to: [Double(frame), 12, 30, 0, 0, 0, 0, 0], mask: 0b101)
            board.cycle(now: Double(frame) * 16, reducesMotion: false)
        }
        XCTAssertEqual(source.wrappedValue, 0.123, "a frame of the result went back to the source")

        dragged(number, to: 40)
        XCTAssertEqual(source.wrappedValue, 0.4, "the user's report landed")
        XCTAssertEqual(percent.wrappedValue, 40)
        _ = renders
    }

    /// A REPORT THAT IS NO EXACT INVERSE LANDS AS THE ROUND TRIP MAKES IT: the source takes what it goes back to,
    /// and the control stands at what the source then makes.
    func testAReportIsCanonicalized() throws {
        let steps = State(wrappedValue: 2.0)
        let shown = steps.projectedValue.convert({ $0 * 10 }, back: { ($0 / 10).rounded() })
        let renders = Renders()
        renders.render(Slider(shown).maximum(100).node)
        board.cycle(now: 0, reducesMotion: false)
        let number = Renderer.shared.number(for: try XCTUnwrap(shown.storage.image))

        dragged(number, to: 34)

        XCTAssertEqual(steps.wrappedValue, 3)
        XCTAssertEqual(shown.wrappedValue, 30, "the control goes to what its source makes")
        _ = renders
    }

    /// A RESULT WITH NO WAY BACK IS READ-ONLY: the program's write is refused and said, a move answers why, and
    /// a control's report leaves the source alone and the control back where the source puts it.
    func testAResultWithNoWayBackIsReadOnly() throws {
        let source = State(wrappedValue: 0.5)
        let shown = source.projectedValue.convert { $0 * 100 }
        let renders = Renders()
        renders.render(Slider(shown).maximum(100).node)
        board.cycle(now: 0, reducesMotion: false)

        shown.wrappedValue = 70
        XCTAssertEqual(shown.wrappedValue, 50, "nothing was written")
        XCTAssertEqual(source.wrappedValue, 0.5)
        XCTAssertTrue(Said.shared.said("derived with no way back"))
        XCTAssertEqual(shown.journey.move(to: 70).outcome, .notStarted(.readOnlyDerived))

        dragged(Renderer.shared.number(for: try XCTUnwrap(shown.storage.image)), to: 70)
        XCTAssertEqual(source.wrappedValue, 0.5, "a report with no way back goes nowhere")
        XCTAssertEqual(shown.wrappedValue, 50, "and the control stands where its source puts it")
        _ = renders
    }

    /// THE PROGRAM'S WRITE MUST BE WHAT ITS SOURCES MAKE OF IT: an exact one goes back and lands; one the round
    /// trip would change is refused before anything is written.
    func testAProgramsWriteIntoAResultMustBeCanonical() {
        let steps = State(wrappedValue: 2.0)
        let shown = steps.projectedValue.convert({ $0 * 10 }, back: { ($0 / 10).rounded() })

        shown.wrappedValue = 40
        XCTAssertEqual(steps.wrappedValue, 4, "an exact value went back")
        XCTAssertEqual(shown.wrappedValue, 40)

        shown.wrappedValue = 47
        XCTAssertEqual(steps.wrappedValue, 4, "47 would come back as 50: refused whole")
        XCTAssertEqual(shown.wrappedValue, 40)
        XCTAssertTrue(Said.shared.said("must be what its sources make of it"))
    }

    /// A MOVE OF A RESULT IS THE WAY BACK FIRST, THEN ONE MOVEMENT OF ITS OWN CHANNEL, under the motion it was
    /// given - the source lands where it goes back to, under its own.
    func testAMoveOfAResultGoesBackThenTravelsOnItsOwnChannel() throws {
        let volume = State(wrappedValue: 0.2)
        let percent = volume.projectedValue.convert({ $0 * 100 }, back: { $0 / 100 })
        let renders = Renders()
        renders.render(Slider(percent).maximum(100).node)
        board.cycle(now: 0, reducesMotion: false)
        _ = board.dirty()

        let run = percent.journey.move(to: 80, .eased(.milliseconds(400), curve: .linear))

        XCTAssertNil(run.outcome, "shown, the result's channel travels")
        XCTAssertEqual(volume.wrappedValue, 0.8, "the source took what the value goes back to, at once")
        board.cycle(now: 16, reducesMotion: false)
        let (_, handed) = try XCTUnwrap(HostAnimatorReport.standing(Renderer.shared.number(for: try XCTUnwrap(percent.storage.image))))
        XCTAssertEqual(handed.destination, [80])
        XCTAssertEqual(handed.motion, .eased(.milliseconds(400), curve: .linear), "under the move's own motion")
        _ = renders
    }

    /// ONE STATE MET TWICE TAKES ONE VALUE: a way back proposing it the same value twice writes it once; two
    /// values for it are a conflict, and nothing is written.
    func testOneStateMetTwiceTakesOneValueOrNone() {
        let side = State(wrappedValue: 2.0)
        let other = State(wrappedValue: 5.0)
        let agreeing = Binding<Double>.multi(side.projectedValue, side.projectedValue)
            .convert({ $0 * $1 }, back: { ($0.squareRoot(), $0.squareRoot()) })

        agreeing.wrappedValue = 9
        XCTAssertEqual(side.wrappedValue, 3, "both proposals were one")

        let conflicting = Binding<Double>.multi(side.projectedValue, side.projectedValue)
            .convert({ $0 + $1 }, back: { ($0, 0) })
        conflicting.wrappedValue = 8
        XCTAssertEqual(side.wrappedValue, 3, "two values for one state: nothing written")
        XCTAssertTrue(Said.shared.said("one state for two values at once"))
        XCTAssertEqual(other.wrappedValue, 5)
    }

    /// A REFUSAL LEAVES NOTHING HALF WRITTEN AND WAKES NOBODY: a source the second refuses with stands as it
    /// stood, its stamp included.
    func testARefusedWriteLeavesNoSourceTouched() {
        let first = State(wrappedValue: 1.0)
        let second = State(wrappedValue: 2.0)
        second.storage.refuses = { $0 > 5 ? "the second takes no more than 5" : nil }
        let pair = Binding<Double>.multi(first.projectedValue, second.projectedValue)
            .convert({ $0 + $1 }, back: { ($0 / 2, $0 / 2) })
        let (stamp, revision) = (first.storage.stamp, first.storage.targetRevision)

        pair.wrappedValue = 20

        XCTAssertEqual(first.wrappedValue, 1, "the first was never written")
        XCTAssertEqual(second.wrappedValue, 2)
        XCTAssertEqual(first.storage.stamp, stamp, "and nothing following it is woken")
        XCTAssertEqual(first.storage.targetRevision, revision)
        XCTAssertTrue(Said.shared.said("the second takes no more than 5"))
    }

    /// THE ARITHMETIC WRITES NOTHING: a state written inside a conversion is refused and said, and the conversion
    /// still answers.
    func testAConversionsArithmeticWritesNoState() {
        let source = State(wrappedValue: 1.0)
        let touched = State(wrappedValue: 0)
        let shown = source.projectedValue.convert { value -> Double in
            touched.wrappedValue += 1
            return value * 2
        }

        XCTAssertEqual(shown.wrappedValue, 2)
        XCTAssertEqual(touched.wrappedValue, 0, "the write was refused")
        XCTAssertTrue(Said.shared.said("written inside a conversion's arithmetic"))
    }

    /// AN ELEMENT GONE TAKES ITS CONVERSION OUT OF THE GRAPH: nothing is worked out for a result nobody wears.
    func testAResultNobodyWearsLeavesTheGraph() {
        let source = State(wrappedValue: 1.0)
        var worked = 0
        let shown = { source.projectedValue.convert { value -> Double in worked += 1; return value * 2 } }
        let renders = Renders()
        renders.render(stack([Slider(shown()).maximum(10).node], id: "root"))
        XCTAssertEqual(board.conversions.count, 1)

        renders.render(stack([], id: "root"))
        XCTAssertEqual(board.conversions.count, 0)
        let before = worked
        source.wrappedValue = 3
        board.cycle(now: 16, reducesMotion: false)
        XCTAssertEqual(worked, before, "nobody wears it: nobody works it out")
        XCTAssertFalse(board.asked)
    }
}
