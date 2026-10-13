// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A picker chooses a value, not a place: the list crosses as the values' captions, the choice as the chosen value's
/// place in it worked out at each build, and a choice the user makes comes back as its value.
@MainActor
final class PickerTests: XCTestCase {
    private enum Span: CaseIterable, Hashable {
        case day, week, month
    }

    func testTheChoiceCrossesAsTheChosenValuesPlace() {
        let span = State(Span.week)
        let node = Picker(Span.allCases, selection: span.projectedValue) { "\($0)".capitalized }.node

        XCTAssertEqual(node.props["options"], .strings(["Day", "Week", "Month"]))
        XCTAssertEqual(node.props["selectedIndex"], .number(1))
    }

    /// A value shows by its description unless the picker is given a caption.
    func testAValueShowsByItsDescriptionUnlessCaptioned() {
        let node = Picker([3, 6, 12], selection: State(6).projectedValue).node

        XCTAssertEqual(node.props["options"], .strings(["3", "6", "12"]))
    }

    /// The list may change its order: the choice stays the value it was.
    func testTheChoiceFollowsItsValueWhereTheListMovesIt() {
        let span = State(Span.week)
        let renders = Renders()
        renders.render(Picker(Span.allCases, selection: span.projectedValue).id("p").node)

        let moved = renders.render(Picker([.month, .day, .week], selection: span.projectedValue).id("p").node)
        XCTAssertEqual(moved.props["selectedIndex"], .number(2), "week, now last")

        let reversed = renders.render(Picker([.week, .day], selection: span.projectedValue).id("p").node)
        XCTAssertEqual(reversed.props["selectedIndex"], .number(0), "week, now first")
    }

    /// Nothing is chosen while the state holds nil, or a value the list does not hold.
    func testNothingIsChosenForNoValueOrOneOutsideTheList() {
        let none = State<Span?>(nil)
        XCTAssertEqual(Picker(Span.allCases, selection: none.projectedValue).node.props["selectedIndex"], .number(-1))

        let outside = State(Span.month)
        XCTAssertEqual(Picker([Span.day, .week], selection: outside.projectedValue).node.props["selectedIndex"],
                       .number(-1))
    }

    /// The user's choice comes back as the value at its place; a place outside the list changes nothing.
    func testAChoiceComesBackAsItsValue() {
        let span = State<Span?>(nil)
        let renders = Renders()
        let patch = renders.render(Picker(Span.allCases, selection: span.projectedValue).node)

        let chosen = patch.events?["selectedIndexChanged"] ?? -1
        renders.fire(chosen, with: [.number(2)])
        XCTAssertEqual(span.wrappedValue, .month)

        renders.fire(chosen, with: [.number(7)])
        XCTAssertEqual(span.wrappedValue, .month, "no value there")
    }
}
