// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// How an element measures a change of its layout's description as it asks the program in its own frame: another
/// description, or another place the motion set out from, asked where the last frame stood - and nothing of a
/// room, or of the parameters moving.
/// Design: docs/design/host/layout.md#asked-in-the-hosts-frame
@MainActor
final class ProgramAskingTests: XCTestCase {
    /// What a program was asked, in order: its parameters' first number and its room's width.
    private final class Asked {
        var at: [(lane: Double, width: Double)] = []
    }

    /// A program numbered `revision` of the views `keys`, `gap` apart across, moved a gap a unit of its one
    /// parameter - shifted by where the motion set out, a `leap` a unit - the last of them at its room's right
    /// edge where `fills`.
    private func program(
        _ revision: UInt64, keys: [Int] = [1, 2, 3], gap: Double = 100, leap: Double = 0, fills: Bool = false,
        asked: Asked? = nil
    ) -> HostLayoutProgram {
        HostLayoutProgram(
            slot: 1, revision: revision, layOut: { _, _ in }, answered: { HostLayoutAnswer() }, frontItemUnit: nil,
            place: { lanes, from, width, _ in
                asked?.at.append((lanes[0], width))
                return HostLayoutAnswer(views: keys.enumerated().map { index, key in
                    let across = fills && index == keys.count - 1
                        ? width - 10 : (Double(index) - lanes[0]) * gap + from[0] * leap
                    return HostLayoutView(key: key, target: Self.place(across))
                })
            },
            axes: [], measuredBy: { _ in }, measure: nil, run: nil)
    }

    private static func place(_ x: Double) -> HostPlacement {
        HostPlacement(
            bounds: Rect(x: x, y: 0, width: 10, height: 10), translationX: 0, translationY: 0, rotation: 0, scaleX: 1,
            scaleY: 1, opacity: 1, zIndex: 0, shade: HostPlacement.unshaded)
    }

    private let room = LayoutSize(width: 300, height: 200)

    /// THE FIRST ANSWER IS NO CHANGE: nothing stood for a view's way to be measured from.
    func testTheFirstAnswerIsNoChange() throws {
        var asking = ProgramAsking()

        let answer = try XCTUnwrap(asking.ask(program(1), at: [0], from: [0], in: room))

        XCTAssertEqual(answer.views.map(\.target.bounds.x), [0, 100, 200])
        XCTAssertEqual(asking.change, ProgramChange())
    }

    /// A PROGRAM THAT ANSWERS AT NO PARAMETERS IS ASKED NONE.
    func testAProgramOfNoPlaceIsAskedNothing() {
        var asking = ProgramAsking()
        let plain = HostLayoutProgram(slot: 1, revision: 1, layOut: { _, _ in }, placed: { [] })

        XCTAssertNil(asking.ask(plain, at: [0], from: [0], in: room))
    }

    /// ANOTHER DESCRIPTION IS MEASURED WHERE THE LAST FRAME STOOD: each view it puts elsewhere there is the
    /// change's, a view it leaves is not, and the frame's own places are asked last.
    func testAnotherDescriptionIsMeasuredWhereTheLastFrameStood() throws {
        var asking = ProgramAsking()
        _ = asking.ask(program(1), at: [0.5], from: [0], in: room)

        let asked = Asked()
        let answer = try XCTUnwrap(asking.ask(program(2, gap: 50, asked: asked), at: [1], from: [0], in: room))

        XCTAssertEqual(asking.change.number, 1)
        XCTAssertEqual(asking.change.places.mapValues(\.bounds.x), [1: -25, 2: 25, 3: 75], "at 0.5, the new gap")
        XCTAssertEqual(answer.views.map(\.target.bounds.x), [-50, 0, 50], "the frame's own places, at 1")
        XCTAssertEqual(asked.at.map(\.lane), [0.5, 1], "where the parameters stand, last")
    }

    /// A VIEW JOINING IS THE CHANGE'S, AT ITS PLACE; the views the change moves nowhere are not.
    func testAViewJoiningIsTheChanges() {
        var asking = ProgramAsking()
        _ = asking.ask(program(1, keys: [1, 2]), at: [0], from: [0], in: room)

        _ = asking.ask(program(2, keys: [1, 2, 3]), at: [0], from: [0], in: room)

        XCTAssertEqual(asking.change.places.mapValues(\.bounds.x), [3: 200])
    }

    /// A DESCRIPTION THAT MOVES NO VIEW IS NO CHANGE: the change before it stands, under its number.
    func testADescriptionThatMovesNoViewIsNoChange() {
        var asking = ProgramAsking()
        _ = asking.ask(program(1), at: [0], from: [0], in: room)
        _ = asking.ask(program(2, gap: 50), at: [0], from: [0], in: room)
        let changed = asking.change

        _ = asking.ask(program(3, gap: 50), at: [0], from: [0], in: room)

        XCTAssertEqual(asking.change, changed)
    }

    /// EACH CHANGE HAS A NUMBER OF ITS OWN: one changed again sets its views out anew.
    func testEachChangeHasItsOwnNumber() {
        var asking = ProgramAsking()
        _ = asking.ask(program(1), at: [0], from: [0], in: room)
        _ = asking.ask(program(2, gap: 50), at: [0], from: [0], in: room)

        _ = asking.ask(program(3), at: [0], from: [0], in: room)

        XCTAssertEqual(asking.change.number, 2)
        XCTAssertEqual(asking.change.places.mapValues(\.bounds.x), [2: 100, 3: 200])
    }

    /// THE PARAMETERS MOVING, AND A NEW ROOM, ARE NO CHANGE: the layout follows both at once, asked once a frame.
    func testTheParametersAndTheRoomAreNoChange() throws {
        var asking = ProgramAsking()
        let asked = Asked()
        let filling = program(1, fills: true, asked: asked)
        _ = asking.ask(filling, at: [0], from: [0], in: room)

        _ = asking.ask(filling, at: [1], from: [0], in: room)
        let wider = try XCTUnwrap(asking.ask(filling, at: [1], from: [0], in: LayoutSize(width: 500, height: 200)))

        XCTAssertEqual(wider.views.map(\.target.bounds.x), [-100, 0, 490])
        XCTAssertEqual(asking.change, ProgramChange())
        XCTAssertEqual(asked.at.count, 3, "once a frame")
    }

    /// A NEW ROOM WITH A NEW DESCRIPTION MEASURES THE DESCRIPTION ALONE: in the room the last frame stood in.
    func testAChangeIsMeasuredInTheRoomTheLastFrameStoodIn() {
        var asking = ProgramAsking()
        _ = asking.ask(program(1, fills: true), at: [0], from: [0], in: room)

        _ = asking.ask(program(2, gap: 50, fills: true), at: [0], from: [0], in: LayoutSize(width: 500, height: 200))

        XCTAssertEqual(asking.change.places.mapValues(\.bounds.x), [2: 50], "the last, at its room's edge, stood")
    }

    /// ANOTHER PLACE THE MOTION SET OUT FROM IS A CHANGE WHERE THE ARITHMETIC READS IT, and none where it does not.
    func testAnotherSetOutIsAChangeWhereTheArithmeticReadsIt() {
        var reading = ProgramAsking()
        _ = reading.ask(program(1, leap: 10), at: [1.25], from: [0], in: room)
        _ = reading.ask(program(1, leap: 10), at: [1.5], from: [1], in: room)
        XCTAssertEqual(reading.change.number, 1)
        XCTAssertEqual(reading.change.places.mapValues(\.bounds.x), [1: -115, 2: -15, 3: 85], "at 1.25, from 1")

        var blind = ProgramAsking()
        _ = blind.ask(program(1), at: [1.25], from: [0], in: room)
        _ = blind.ask(program(1), at: [1.5], from: [1], in: room)
        XCTAssertEqual(blind.change, ProgramChange())
    }
}
