// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A gallery under the hand: the hand moves the run of cards on the display's frames and builds no card, the
/// position is the card it names as it passes, and let go the run comes onto a card.
@MainActor
final class GalleryViewHandTests: XCTestCase {
    private let bench = LayoutBench()

    /// The room the galleries are laid out in.
    private let room = Rect(x: 0, y: 0, width: 352, height: 400)

    /// How far the hand travels for one card: as far as the card in front goes on the wheel, at its stated size.
    private let reach = 176.0 * 0.52

    private func gallery(_ count: Int) -> GalleryView<Range<Int>, Int> {
        GalleryView(0..<count) { number in
            Text("\(number)")
        }
    }

    /// A FRAME OF THE HAND BUILDS NOBODY: the hand moves the run on the display's own frames, and no body is built
    /// for a move within the card in front.
    func testAFrameOfTheHandBuildsNobody() {
        bench.laid({ self.gallery(6).node }, room: room)

        bench.hand(.began)
        let built = HostBoundary.tally.built

        // Ten moves within the card in front, a few points each.
        for step in 1...10 {
            bench.hand(.changed, moved: Point(x: -4, y: 0))

            XCTAssertEqual(HostBoundary.tally.built, built, "move \(step) of the hand built a body")
        }
    }

    /// A DECK IS SWIPED A CARD AT A TIME, however far the hand goes.
    func testADeckIsSwipedACardAtATime() {
        let shown = State(0)
        bench.laid({ self.gallery(5).arrangement(.deck).position(shown.projectedValue).node }, room: room)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -20 * reach, y: 0))
        XCTAssertEqual(shown.wrappedValue, 1, "one card, not the last")
    }

    /// A HAND OF NO NUMBER - a toolkit saying it moved by not a number, or endlessly - moves nothing and never stops
    /// the application.
    func testAHandOfNoNumberMovesNothing() {
        let shown = State(0)
        bench.laid({ self.gallery(5).position(shown.projectedValue).node }, room: room)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: .nan, y: .nan))
        bench.hand(.changed, moved: Point(x: .infinity, y: 0))
        bench.hand(.ended, velocity: Point(x: .nan, y: .infinity))
        XCTAssertEqual(shown.wrappedValue, 0)
    }

    /// THE HAND NAMES THE CARD IT PASSES: as it crosses halfway between two cards the position is the nearer one, in
    /// the frame that names it; a move between two names nothing new, and a card the run cannot reach is not one it
    /// names.
    func testTheHandNamesTheCardItPasses() {
        let shown = State(0)
        bench.laid({ self.gallery(5).position(shown.projectedValue).node }, room: room)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -2.6 * reach, y: 0))
        XCTAssertEqual(shown.wrappedValue, 3)

        bench.hand(.changed, moved: Point(x: -0.3 * reach, y: 0))
        XCTAssertEqual(shown.wrappedValue, 3, "a move between two cards names nothing new")

        bench.hand(.changed, moved: Point(x: 2.5 * reach, y: 0))
        XCTAssertEqual(shown.wrappedValue, 0)

        bench.hand(.changed, moved: Point(x: -20 * reach, y: 0))
        XCTAssertEqual(shown.wrappedValue, 4, "a card past the last is the last")
    }

    /// A ROOM THAT GROWS KEEPS THE CARD IN FRONT: the run stands on its parameters, which a room does not move - a
    /// phone turned shows the card the user left there.
    func testARoomThatGrowsKeepsTheCardInFront() throws {
        let shown = State(0)
        bench.laid({ self.gallery(5).position(shown.projectedValue).node }, room: room)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -4 * reach, y: 0))
        bench.hand(.ended)
        XCTAssertEqual(shown.wrappedValue, 4)

        bench.room(700, 300)
        bench.frames(2)

        XCTAssertEqual(shown.wrappedValue, 4, "the card the user left in front")
        XCTAssertEqual(try XCTUnwrap(bench.journey).destination, [4])
    }

    /// A RUN LET GO BETWEEN TWO CARDS COMES ONTO THE NEARER, where it is going at once. A run let go on a card is
    /// left there.
    func testARunLetGoBetweenTwoCardsTravelsOnToTheNearer() throws {
        bench.laid({ self.gallery(5).node }, room: room)

        bench.hand(.began)
        bench.hand(.changed, moved: Point(x: -1.4 * reach, y: 0))
        bench.hand(.ended)
        XCTAssertEqual(try XCTUnwrap(bench.journey).destination[0], 1, accuracy: 0.001, "the nearer card")

        // The run comes onto it, and the hand lets go of it on the card.
        bench.frames(60)
        bench.hand(.began)
        bench.hand(.ended)

        let left = try XCTUnwrap(bench.journey)
        XCTAssertEqual(left.destination[0], 1, accuracy: 0.001, "a run on a card stays")
        XCTAssertEqual(left.value[0], 1, accuracy: 0.001)
    }

    /// A THROW GOES ON AS `release` SAYS: the same swipe let go with speed, carried for three seconds' worth, comes
    /// to rest two cards on, where the light friction of a gallery that says nothing slides it back to the first.
    func testAThrowGoesOnAsItsReleaseSays() {
        for (throwing, card) in [(Motion?.none, 0), (.eased(.seconds(3)), 2)] {
            let shown = State(0)
            let bench = LayoutBench()
            bench.laid({
                let swiped = self.gallery(5).position(shown.projectedValue)
                return (throwing.map { swiped.release(.projected($0)) } ?? swiped).node
            }, room: room)

            bench.hand(.began)
            bench.hand(.changed, moved: Point(x: -0.1 * reach, y: 0))
            bench.hand(.ended, velocity: Point(x: -200, y: 0))

            XCTAssertEqual(shown.wrappedValue, card, "thrown \(throwing.map { "\($0.kind)" } ?? "as a gallery is")")
        }
    }
}
