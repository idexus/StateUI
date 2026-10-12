// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A value inside a range, and words in a case, the same on every host.
@MainActor
final class ValueArithmeticTests: XCTestCase {
    /// A range's ends stand in order whichever the tree gave first; a step that does not move is 1.
    func testARangeStandsInOrderAndAStepMoves() {
        XCTAssertTrue(ValueArithmetic.range(10, 2) == (2, 10))
        XCTAssertTrue(ValueArithmetic.range(2, 10) == (2, 10))
        XCTAssertEqual(ValueArithmetic.step(0.25), 0.25)
        XCTAssertEqual([0, -1, .nan, .infinity].map(ValueArithmetic.step), [1, 1, 1, 1])
    }

    /// A control of a range is written the tree's value where the tree changed it or an end - a range widened over a
    /// value the control stood clamped at shows it - and otherwise keeps the one it shows.
    func testARangeThatMovesTakesTheTreesValue() {
        func written(changed: Set<Prop>, tree: Double?) -> Double {
            let values = ElementValues<SliderContract>(changed: changed) { key in
                key == SliderContract.value.token ? tree.map { .number($0) } : nil
            }
            return values.written(
                SliderContract.value, within: [SliderContract.minimum, SliderContract.maximum], standing: 10)
        }

        XCTAssertEqual(written(changed: [SliderContract.minimum.token], tree: 25), 25, "the range moved")
        XCTAssertEqual(written(changed: [SliderContract.value.token], tree: 25), 25, "the value changed")
        XCTAssertEqual(written(changed: [], tree: 25), 10, "nothing the tree changed: the hand on the control stays")
        XCTAssertEqual(written(changed: [SliderContract.maximum.token], tree: nil), 10, "no value in the tree")
    }

    /// A share of work past an end stands at that end; one that is no number stands at the start.
    func testAShareOfWorkStandsInsideItsEnds() {
        XCTAssertEqual([0.5, 1.5, -1, .nan].map(ValueArithmetic.share), [0.5, 1, 0, 0])
    }

    /// A slider's key moves a hundredth of its range, a page a tenth.
    func testASlidersStepsAreShareOfItsRange() {
        XCTAssertTrue(ValueArithmetic.sliderSteps(lower: 0, upper: 200) == (2, 20))
    }

    /// A stepped number is written with as many decimals as its step and its range take, and no more than six.
    func testANumberTakesTheDecimalsItsStepTakes() {
        XCTAssertEqual(ValueArithmetic.decimals(of: [1, 0, 10, 3]), 0)
        XCTAssertEqual(ValueArithmetic.decimals(of: [0.25, 0, 1, 0.5]), 2)
        XCTAssertEqual(ValueArithmetic.decimals(of: [0.1, 0, 1, .nan]), 1)
        XCTAssertEqual(ValueArithmetic.decimals(of: [1.0 / 3]), 6)
    }

    /// A stepper shows its steps alone: on its way, the step of its destination's nearest where the journey
    /// stands, between there and the destination; at rest, its value - written as exactly as its step and its
    /// destination are.
    func testAStepperShowsTheStepsOfItsDestination() {
        func shown(
            _ value: Double, _ destination: Double, step: Double = 1, _ lower: Double = 0, _ upper: Double = 30
        ) -> Double {
            ValueArithmetic.stepped(value, toward: destination, step: step, lower: lower, upper: upper)
        }
        XCTAssertEqual(shown(24.999999999989246, 25), 25, "the last approach shows the destination")
        XCTAssertEqual(shown(4, 25), 4, "where it set out")
        XCTAssertEqual(shown(4.3, 25), 5, "the next step on its way, never 4.3")
        XCTAssertEqual(shown(2, 5.2, step: 2, 0, 10), 3.2, "a step of the destination's own, never behind the start")
        XCTAssertEqual(shown(5.5, 5.2, step: 2, 0, 10), 5.2, "never past where it lands")
        XCTAssertEqual(shown(5.2, 5.2, step: 2, 0, 10), 5.2, "at rest, the value itself")
        XCTAssertEqual(shown(0.30000000000000004, 0.1, step: 0.1, 0, 1), 0.3)
        XCTAssertEqual(shown(31, 25, 20, 30), 30, "on its way down, within the range")
        XCTAssertEqual(shown(.nan, 25, 20, 30), 25)
    }

    /// Words stand as written, or in one case throughout.
    func testWordsTakeTheirCase() {
        XCTAssertEqual(TextCase.uppercase.applied(to: "Mixed Words"), "MIXED WORDS")
        XCTAssertEqual(TextCase.lowercase.applied(to: "Mixed Words"), "mixed words")
        XCTAssertEqual(TextCase.none.applied(to: "Mixed Words"), "Mixed Words")
        XCTAssertEqual(TextCase.default.applied(to: "Mixed Words"), "Mixed Words")
    }
}
