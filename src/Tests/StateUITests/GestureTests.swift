// What a gesture reports, and how it gets here.
//
// A gesture carries more than one value - a status and a translation, a scale
// and an origin - so a payload is one value per property, in the order MAUI
// declares them, each already typed. This is the file that pins that format
// down from the reading end; the writing end is the renderer's ApplyGestures.

import XCTest
@testable import StateUI

final class GestureTests: XCTestCase {
    func testAGestureArrivesAlreadyTyped() {
        let renders = Renders()
        var swipes: [SwipeDirection] = []
        var pans: [PanUpdate] = []
        var pinches: [PinchUpdate] = []
        var points: [Point] = []

        let patch = renders.render(
            BoxView(.cornflowerBlue)
                .onSwiped { swipes.append($0) }
                .onPanUpdated { pans.append($0) }
                .onPinchUpdated { pinches.append($0) }
                .onPointerMoved { points.append($0) }
                .body)

        let events = patch.events ?? [:]

        renders.fire(events["swiped"] ?? -1, with: [.enumeration(SwipeDirection.left.rawValue)])
        renders.fire(events["panUpdated"] ?? -1, with: [
            .enumeration(GestureStatus.running.rawValue), .number(12.5), .number(-3),
        ])
        renders.fire(events["pinchUpdated"] ?? -1, with: [
            .enumeration(GestureStatus.completed.rawValue), .number(1.25), .numbers([0.5, 0.75]),
        ])
        renders.fire(events["pointerMoved"] ?? -1, with: [.numbers([12.5, 30])])

        XCTAssertEqual(swipes, [.left])

        XCTAssertEqual(pans.first?.status, .running)
        XCTAssertEqual(pans.first?.totalX, 12.5)
        XCTAssertEqual(pans.first?.totalY, -3)

        XCTAssertEqual(pinches.first?.status, .completed)
        XCTAssertEqual(pinches.first?.scale, 1.25)
        XCTAssertEqual(pinches.first?.scaleOrigin, Point(x: 0.5, y: 0.75))

        XCTAssertEqual(points, [Point(x: 12.5, y: 30)])
    }

    /// A payload that cannot be read leaves the handler alone rather than
    /// inventing a value - the same rule the renderer follows for a property it
    /// does not recognize.
    ///
    /// The three ways one fails: a value short, the status sent as a plain
    /// NUMBER where a member of a closed vocabulary is wanted, and nothing at
    /// all. The middle one is the shape a host that stopped translating would
    /// send, which makes it the one worth having.
    func testAPayloadThatMakesNoSenseIsIgnored() {
        let renders = Renders()
        var pans = 0

        let patch = renders.render(BoxView().onPanUpdated { _ in pans += 1 }.body)
        let id = patch.events?["panUpdated"] ?? -1

        renders.fire(id, with: [.enumeration(GestureStatus.running.rawValue), .number(12.5)])
        renders.fire(id, with: [
            .number(Double(GestureStatus.running.rawValue)), .number(1), .number(2),
        ])
        renders.fire(id, with: [])

        XCTAssertEqual(pans, 0)

        renders.fire(id, with: [
            .enumeration(GestureStatus.started.rawValue), .number(0), .number(0),
        ])
        XCTAssertEqual(pans, 1)
    }

    /// The same rule for a swipe, where it matters most: a garbled payload
    /// read as an EMPTY direction set would run the handler with a value no
    /// direction test can tell from a real swipe.
    func testASwipeThatMakesNoSenseIsIgnoredToo() {
        let renders = Renders()
        var swipes = 0

        let patch = renders.render(BoxView().onSwiped { _ in swipes += 1 }.body)
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
    /// MAUI on iOS and Mac Catalyst raises Swiped with the directions the
    /// recognizer was CONFIGURED for rather than the one the finger went, so a
    /// view listening every way sends exactly this - a true report of a message
    /// that says nothing, and refusing it is what leaves such a view silent on
    /// Apple while Android works. The renderer attaches one recognizer per
    /// direction, so a mask cannot be assembled in the first place.
    func testASetOfDirectionsIsNotADirection() {
        let renders = Renders()
        var swipes: [SwipeDirection] = []

        let patch = renders.render(BoxView().onSwiped { swipes.append($0) }.body)
        let id = patch.events?["swiped"] ?? -1

        // What the platform sent, and the same thing spelled tidily.
        renders.fire(id, with: [.enumeration(SwipeDirection.all.rawValue)])
        renders.fire(id, with: [.enumeration(SwipeDirection([.left, .right]).rawValue)])

        XCTAssertEqual(swipes, [], "a set of directions does not answer 'which way'")

        renders.fire(id, with: [.enumeration(SwipeDirection.up.rawValue)])
        XCTAssertEqual(swipes, [.up])
    }

    func testAGestureSaysWhatItListensForBesideWhatItDoes() {
        let renders = Renders()

        let patch = renders.render(
            BoxView()
                .onSwiped(direction: [.up, .down], threshold: 40) { _ in }
                .onPanUpdated(touchCount: 2) { _ in }
                .onTapped(numberOfTapsRequired: 2) {}
                .body)

        // The bits this library numbers them with - up 4, down 8 - as the one
        // number a bit set travels as.
        XCTAssertEqual(patch.props["swipeDirection"], .enumeration(12))
        XCTAssertEqual(patch.props["swipeThreshold"], .number(40))
        XCTAssertEqual(patch.props["panTouchCount"], .number(2))
        XCTAssertEqual(patch.props["numberOfTapsRequired"], .number(2))
    }

    /// A swipe that listens for nothing recognizes nothing, so the default is
    /// every direction rather than none.
    func testAViewListensForEveryDirectionUnlessItSaysOtherwise() {
        let renders = Renders()
        let patch = renders.render(BoxView().onSwiped { _ in }.body)

        XCTAssertEqual(patch.props["swipeDirection"], .enumeration(15), "every bit there is")
        XCTAssertNil(patch.props["swipeThreshold"], "a threshold nobody set is not sent")
    }

    /// The raw payload, beside the typed handler rather than instead of it.
    ///
    /// A typed modifier drops a payload it cannot read, which is right for an
    /// author and useless for anyone asking why nothing happens. `.onEvent` is
    /// what tells a gesture that stopped reporting from a payload this side
    /// cannot read - and it only helps if BOTH still run.
    func testTheRawPayloadCanBeSeenBesideTheTypedHandler() {
        let renders = Renders()
        var typed = 0
        var raw: [[PropValue]] = []

        let patch = renders.render(
            BoxView()
                .onPinchUpdated { _ in typed += 1 }
                .onEvent(.pinchUpdated) { raw.append($0) }
                .body)

        let id = patch.events?["pinchUpdated"] ?? -1

        // The second is the first with its status sent as a plain number, which
        // is the whole difference between a report and a refusal.
        let readable: [PropValue] = [
            .enumeration(GestureStatus.running.rawValue), .number(1.25), .numbers([0.5, 0.5]),
        ]
        let garbled: [PropValue] = [
            .number(Double(GestureStatus.running.rawValue)), .number(1.25), .numbers([0.5, 0.5]),
        ]

        renders.fire(id, with: readable)
        renders.fire(id, with: garbled)

        XCTAssertEqual(typed, 1, "the typed handler read the one it could")
        XCTAssertEqual(raw, [readable, garbled],
                       "and the raw one saw both, including what the typed one dropped")
    }

    /// Every typed gesture modifier composes, so two of the same kind both run.
    func testTwoHandlersForOneGestureBothRun() {
        let renders = Renders()
        var first = 0
        var second = 0

        let patch = renders.render(
            BoxView()
                .onTapped { first += 1 }
                .onTapped { second += 1 }
                .body)

        renders.fire(patch.events?["tapped"] ?? -1)

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1, "the second handler ran too, rather than replacing the first")
    }

    func testWhatADragCarriesIsDecidedBeforeItStarts() {
        let renders = Renders()
        var dropped: [String] = []

        let patch = renders.render(
            VStack {
                Label("Alpha")
                    .draggable(text: "Alpha")
                    .id("source")

                Border {
                    Label("Drop here")
                }
                .onDrop { dropped.append($0) }
                .id("target")
            }
            .body)

        let source = patch.child("source")
        XCTAssertEqual(source?.props["dragText"], .string("Alpha"))
        XCTAssertEqual(source?.props["canDrag"], .bool(true))

        let target = patch.child("target")
        XCTAssertEqual(target?.props["allowDrop"], .bool(true),
                       "a view that handles a drop is a view that allows one")

        renders.fire(target?.events?["drop"] ?? -1, with: [.string("Alpha")])
        XCTAssertEqual(dropped, ["Alpha"])
    }
}
