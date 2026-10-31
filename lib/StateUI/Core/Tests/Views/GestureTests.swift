// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a gesture reports, and how it gets here.
//
// A gesture carries more than one value - a status and a translation, a scale
// and an origin - so a payload is one value per property, in the order its
// update type declares them, each already typed. This is the file that pins
// that format down from the reading end; the writing end is each host's
// gesture adapter.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class GestureTests: XCTestCase {
    func testAGestureArrivesAlreadyTyped() {
        let renders = Renders()
        var swipes: [SwipeDirection] = []
        var pans: [PanUpdate] = []
        var pinches: [PinchUpdate] = []
        var turns: [RotationUpdate] = []
        var points: [Point] = []

        let patch = renders.render(
            Rectangle()
                .fill(.cornflowerBlue)
                .onSwiped { swipes.append($0) }
                .onPanUpdated { pans.append($0) }
                .onPinchUpdated { pinches.append($0) }
                .onRotationUpdated { turns.append($0) }
                .onPointerMoved { points.append($0) }
                .node)

        let events = patch.events?.handlers ?? [:]

        renders.fire(events["swiped"] ?? -1, with: [.enumeration(SwipeDirection.left.rawValue)])
        renders.fire(events["panUpdated"] ?? -1, with: [
            .enumeration(GesturePhase.changed.rawValue), .numbers([12.5, -3]), .numbers([400, -80]),
        ])
        renders.fire(events["pinchUpdated"] ?? -1, with: [
            .enumeration(GesturePhase.ended.rawValue), .number(1.25), .numbers([0.5, 0.75]), .number(2),
        ])
        renders.fire(events["rotationUpdated"] ?? -1, with: [
            .enumeration(GesturePhase.changed.rawValue), .number(30), .number(90),
        ])
        renders.fire(events["pointerMoved"] ?? -1, with: [.numbers([12.5, 30])])

        XCTAssertEqual(swipes, [.left])

        XCTAssertEqual(pans.first?.phase, .changed)
        XCTAssertEqual(pans.first?.totalX, 12.5)
        XCTAssertEqual(pans.first?.totalY, -3)
        XCTAssertEqual(pans.first?.velocityX, 400)
        XCTAssertEqual(pans.first?.velocityY, -80)

        XCTAssertEqual(pinches.first?.phase, .ended)
        XCTAssertEqual(pinches.first?.scale, 1.25)
        XCTAssertEqual(pinches.first?.scaleOrigin, Point(x: 0.5, y: 0.75))
        XCTAssertEqual(pinches.first?.velocity, 2)

        XCTAssertEqual(turns.first?.phase, .changed)
        XCTAssertEqual(turns.first?.angle, 30)
        XCTAssertEqual(turns.first?.velocity, 90)

        XCTAssertEqual(points, [Point(x: 12.5, y: 30)])
    }

    /// A payload that cannot be read leaves the handler alone rather than
    /// inventing a value - the same rule a host follows for a property it does
    /// not recognize.
    ///
    /// The three ways one fails: a value short, the status sent as a plain
    /// NUMBER where a member of a closed vocabulary is wanted, and nothing at
    /// all. The middle one is the shape a host that stopped translating would
    /// send, which makes it the one worth having.
    func testAPayloadThatMakesNoSenseIsIgnored() {
        let renders = Renders()
        var pans = 0

        let patch = renders.render(Rectangle().onPanUpdated { _ in pans += 1 }.node)
        let id = patch.events?["panUpdated"] ?? -1

        renders.fire(id, with: [.enumeration(GesturePhase.changed.rawValue), .numbers([12.5, 0])])
        renders.fire(id, with: [
            .number(Double(GesturePhase.changed.rawValue)), .numbers([1, 2]), .numbers([0, 0]),
        ])
        renders.fire(id, with: [])

        XCTAssertEqual(pans, 0)

        renders.fire(id, with: [
            .enumeration(GesturePhase.began.rawValue), .numbers([0, 0]), .numbers([0, 0]),
        ])
        XCTAssertEqual(pans, 1)
    }

    /// The same rule for a swipe, where it matters most: a garbled payload
    /// read as an EMPTY direction set would run the handler with a value no
    /// direction test can tell from a real swipe.
    func testASwipeThatMakesNoSenseIsIgnoredToo() {
        let renders = Renders()
        var swipes = 0

        let patch = renders.render(Rectangle().onSwiped { _ in swipes += 1 }.node)
        let id = patch.events?["swiped"] ?? -1

        // A direction sent as a plain number, and a payload with nothing in it.
        renders.fire(id, with: [.number(Double(SwipeDirection.left.rawValue))])
        renders.fire(id, with: [])

        XCTAssertEqual(swipes, 0)

        renders.fire(id, with: [.enumeration(SwipeDirection.left.rawValue)])
        XCTAssertEqual(swipes, 1)
    }

    /// The payload a platform really sends, kept as a case of its own because
    /// the refusals above are invented and this one is a measurement.
    ///
    /// UIKit's swipe recognizer reports the directions it was CONFIGURED for
    /// rather than the one the finger went, so a view listening every way
    /// sends exactly this - a true report of a message that says nothing, and
    /// refusing it is what leaves such a view silent on Apple platforms while
    /// Android works. A host that attaches one recognizer per direction never
    /// assembles a mask in the first place.
    func testASetOfDirectionsIsNotADirection() {
        let renders = Renders()
        var swipes: [SwipeDirection] = []

        let patch = renders.render(Rectangle().onSwiped { swipes.append($0) }.node)
        let id = patch.events?["swiped"] ?? -1

        // What the platform sent, and the same thing spelled tidily.
        renders.fire(id, with: [.enumeration(SwipeDirection.all.rawValue)])
        renders.fire(id, with: [.enumeration(SwipeDirection([.left, .right]).rawValue)])

        XCTAssertEqual(swipes, [], "a set of directions does not answer 'which way'")

        renders.fire(id, with: [.enumeration(SwipeDirection.up.rawValue)])
        XCTAssertEqual(swipes, [.up])
    }

    /// Two swipe handlers, each for its own direction, listen together, and each hears its own direction alone.
    func testTwoSwipeHandlersListenTogetherEachForItsOwn() {
        let renders = Renders()
        var heard: [String] = []

        let patch = renders.render(Rectangle()
            .onSwiped(direction: .left) { _ in heard.append("next") }
            .onSwiped(direction: .right) { _ in heard.append("previous") }
            .node)
        let id = patch.events?["swiped"] ?? -1

        XCTAssertEqual(patch.props["swipeDirection"], .enumeration(SwipeDirection([.left, .right]).rawValue))

        renders.fire(id, with: [.enumeration(SwipeDirection.left.rawValue)])
        renders.fire(id, with: [.enumeration(SwipeDirection.right.rawValue)])

        XCTAssertEqual(heard, ["next", "previous"])
    }

    /// Two drop handlers, each for its own kinds of file, take the files of both, and each hears its own kinds.
    func testTwoDropHandlersTakeEachTheirOwnFiles() {
        let renders = Renders()
        var heard: [String] = []
        let text = FileType("Text", extensions: ["txt"])
        let picture = FileType("Picture", extensions: ["png"])

        let patch = renders.render(Rectangle()
            .onDrop(files: [text]) { files in heard += files.map { "text " + $0.name } }
            .onDrop(files: [picture]) { files in heard += files.map { "picture " + $0.name } }
            .node)

        XCTAssertEqual(patch.props["droppedFileTypes"], [text, picture].propValue)

        renders.fire(patch.events?["filesDropped"] ?? -1, with: [
            .values([ChosenFile(address: "a", name: "notes.txt").propValue, ChosenFile(address: "b", name: "cat.png").propValue]),
        ])

        XCTAssertEqual(heard, ["text notes.txt", "picture cat.png"])
    }

    /// A view hears one count of taps: a single and a double tap on one view are said, not silently one of them.
    func testTapsOfTwoCountsOnOneViewAreSaid() {
        Renders().render(Rectangle().onTapped {}.onTapped(count: 2) {}.node)

        XCTAssertTrue(hasComplained("hears taps of one count"))
    }

    /// A hold says how long it waits where it is asked to, and is heard as `held`; unsaid, the platform's own
    /// time stands.
    func testAHoldSaysItsTimeBesideWhatItDoes() {
        let renders = Renders()
        var held = 0

        let patch = renders.render(Rectangle().onHeld(minimum: .milliseconds(800)) { held += 1 }.node)
        XCTAssertEqual(patch.props["holdDuration"], .number(800))
        renders.fire(patch.events?["held"] ?? -1, with: [])
        XCTAssertEqual(held, 1)

        let unsaid = Renders().render(Rectangle().onHeld {}.node)
        XCTAssertNil(unsaid.props["holdDuration"], "the platform's own time")
        XCTAssertNotNil(unsaid.events?["held"])
    }

    /// A view waits one time for a hold: two are said, the last standing; a hold saying no time keeps the one said.
    func testHoldsOfTwoTimesOnOneViewAreSaid() {
        let kept = Renders().render(Rectangle().onHeld(minimum: .seconds(1)) {}.onHeld {}.node)
        XCTAssertEqual(kept.props["holdDuration"], .number(1000), "a hold saying no time erases nothing")

        Renders().render(Rectangle().onHeld(minimum: .seconds(1)) {}.onHeld(minimum: .seconds(2)) {}.node)
        XCTAssertTrue(hasComplained("waits one time for a hold"))
    }

    /// A pan for one touch count beside a pan for another is said; a pan saying no count keeps the one said.
    func testPansOfTwoTouchCountsOnOneViewAreSaid() {
        let kept = Renders().render(Rectangle().onPanUpdated(touchCount: 2) { _ in }.onPanUpdated { _ in }.node)
        XCTAssertEqual(kept.props["panTouchCount"], .number(2), "a pan saying no count erases nothing")

        Renders().render(Rectangle().onPanUpdated(touchCount: 1) { _ in }.onPanUpdated(touchCount: 2) { _ in }.node)
        XCTAssertTrue(hasComplained("hears pans of one touch count"))
    }

    func testAGestureSaysWhatItListensForBesideWhatItDoes() {
        let renders = Renders()

        let patch = renders.render(
            Rectangle()
                .onSwiped(direction: [.up, .down], threshold: 40) { _ in }
                .onPanUpdated(touchCount: 2) { _ in }
                .onTapped(count: 2) {}
                .node)

        // The bits this library numbers them with - up 4, down 8 - as the one
        // number a bit set travels as.
        XCTAssertEqual(patch.props["swipeDirection"], .enumeration(12))
        XCTAssertEqual(patch.props["swipeThreshold"], .number(40))
        XCTAssertEqual(patch.props["panTouchCount"], .number(2))
        XCTAssertEqual(patch.props["tapCount"], .number(2))
    }

    /// A swipe that listens for nothing recognizes nothing, so the default is
    /// every direction rather than none.
    func testAViewListensForEveryDirectionUnlessItSaysOtherwise() {
        let renders = Renders()
        let patch = renders.render(Rectangle().onSwiped { _ in }.node)

        XCTAssertEqual(patch.props["swipeDirection"], .enumeration(15), "every bit there is")
        XCTAssertNil(patch.props["swipeThreshold"], "a threshold nobody set is not sent")
    }

    /// A report of another shape than the view's contract declares reaches
    /// no handler - the typed modifier's, nor one heard through the member
    /// itself beside it. Both read what the contract declares, and a report
    /// that is not that is refused whole and said once, naming what arrived.
    func testAReportOfAnotherShapeReachesNoHandler() {
        let renders = Renders()
        var typed = 0
        var heard: [String] = []

        let patch = renders.render(
            Rectangle()
                .onPinchUpdated { _ in typed += 1 }
                .onEvent(ViewContract.pinchUpdated) { phase, scale, origin, velocity in
                    heard.append("\(phase) \(scale) \(origin.x),\(origin.y) \(velocity)")
                }
                .node)

        let id = patch.events?["pinchUpdated"] ?? -1

        // The second is the first with its phase sent as a plain number, which
        // is the whole difference between a report and a refusal.
        let readable: [PropValue] = [
            .enumeration(GesturePhase.changed.rawValue), .number(1.25), .numbers([0.5, 0.5]), .number(0),
        ]
        let garbled: [PropValue] = [
            .number(Double(GesturePhase.changed.rawValue)), .number(1.25), .numbers([0.5, 0.5]), .number(0),
        ]

        renders.fire(id, with: readable)
        renders.fire(id, with: garbled)

        XCTAssertEqual(typed, 1, "the typed modifier read the one it could")
        XCTAssertEqual(heard, ["changed 1.25 0.5,0.5 0.0"],
                       "and so did the member's handler beside it, and nothing else")
    }

    /// Every typed gesture modifier composes, so two of the same kind both run.
    func testTwoHandlersForOneGestureBothRun() {
        let renders = Renders()
        var first = 0
        var second = 0

        let patch = renders.render(
            Rectangle()
                .onTapped { first += 1 }
                .onTapped { second += 1 }
                .node)

        renders.fire(patch.events?["tapped"] ?? -1)

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1, "the second handler ran too, rather than replacing the first")
    }

    func testWhatADragCarriesIsDecidedBeforeItStarts() {
        let renders = Renders()
        var dropped: [String] = []

        let patch = renders.render(
            VStack {
                Text("Alpha")
                    .draggable(text: "Alpha")
                    .id("source")

                ZStack {
                    Text("Drop here")
                }
                .onDrop { dropped.append($0) }
                .id("target")
            }
            .node)

        let source = patch.child("source")
        XCTAssertEqual(source?.props["dragText"], .string("Alpha"))
        XCTAssertEqual(source?.props["canDrag"], .bool(true))

        let target = patch.child("target")
        XCTAssertEqual(target?.props["allowsDrop"], .bool(true),
                       "a view that handles a drop is a view that allows one")

        renders.fire(target?.events?["drop"] ?? -1, with: [.string("Alpha")])
        XCTAssertEqual(dropped, ["Alpha"])
    }
}
