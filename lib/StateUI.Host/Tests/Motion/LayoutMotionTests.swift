// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A layout's children travelling to their places: what a patch said travels, what the room or a read frame gave
/// arrives, and a child on its way bends, keeps its way, or stops as it leaves.
@MainActor
final class LayoutMotionTests: XCTestCase {
    /// A child a patch moves starts from where it stood, travels on the layout's law, and lands exactly on its new
    /// place; the first arrangement is an arrival.
    func testAChildAPatchMovesTravelsToItsNewPlace() {
        let layout = HandWoundLayout()
        let moved = Placed()
        layout.arrange([(moved, 2, Self.row(1))])
        XCTAssertEqual(moved.placedFrame, Self.row(1), "the first arrangement is an arrival")

        layout.arrange([(moved, 2, Self.row(0))])
        XCTAssertEqual(moved.placedFrame, Self.row(1), "a child starts from where it stood")

        layout.frame(at: 100)
        XCTAssertEqual(moved.placedFrame.y, 20, accuracy: 1e-9, "halfway through a linear 200 ms animation")

        layout.frame(at: 200)
        XCTAssertEqual(moved.placedFrame, Self.row(0), "and it lands exactly")
        XCTAssertFalse(layout.animator.isMoving)
    }

    /// A child that joins a standing layout is at its place at once and fades in under the layout's law; the
    /// children of a first arrangement are simply there.
    func testAChildThatJoinsAStandingLayoutFadesIn() {
        let layout = HandWoundLayout()
        let first = Placed()
        layout.arrange([(first, 1, Self.row(0))])
        XCTAssertEqual(layout.fades, [:], "a first arrangement does not fade")

        let joined = Placed()
        layout.arrange([(first, 1, Self.row(0)), (joined, 2, Self.row(1))])

        XCTAssertEqual(joined.placedFrame, Self.row(1))
        XCTAssertEqual(layout.fades, [2: .eased(200, .linear)])
        XCTAssertFalse(layout.animator.isMoving, "nothing travels to where it already is")
    }

    /// Where the user asks for less movement, every child arrives and none fades in.
    func testWithLessMotionEveryChildArrives() {
        let layout = HandWoundLayout()
        layout.reducesMotion = true
        let moved = Placed()
        layout.arrange([(moved, 1, Self.row(1))])

        layout.arrange([(moved, 1, Self.row(0)), (Placed(), 2, Self.row(1))])

        XCTAssertEqual(moved.placedFrame, Self.row(0))
        XCTAssertEqual(layout.fades, [:])
        XCTAssertFalse(layout.animator.isMoving)
    }

    /// A room that resizes holds nothing different: its children follow it exactly, with or without a patch,
    /// because a child that glides after the user's own hand is late on every frame.
    func testARoomThatResizesPlacesItsChildrenAtOnce() {
        let layout = HandWoundLayout()
        let moved = Placed()
        layout.arrange([(moved, 1, Self.row(0, x: 150))], width: 200)

        layout.arrange([(moved, 1, Self.row(0, x: 350))], width: 400, patched: false)
        XCTAssertEqual(moved.placedFrame, Self.row(0, x: 350), "the child follows the room exactly")

        layout.arrange([(moved, 1, Self.row(0, x: 150))], width: 200)
        XCTAssertEqual(moved.placedFrame, Self.row(0, x: 150), "its width is its parent's to say, patch or not")
        XCTAssertFalse(layout.animator.isMoving, "a resize starts no animation")
    }

    /// Where a frame under a layout is read, every child arrives: each frame of an animation would hand what reads
    /// the frame a room nobody chose.
    func testALayoutWhoseFramesAreReadPlacesItsChildrenAtOnce() {
        let layout = HandWoundLayout()
        layout.places.framesRead = true
        let moved = Placed()
        layout.arrange([(moved, 1, Self.row(1))])

        layout.arrange([(moved, 1, Self.row(0))])

        XCTAssertEqual(moved.placedFrame, Self.row(0))
        XCTAssertFalse(layout.animator.isMoving)
    }

    /// A size a child states for itself arrives at once - it is either still or moving on its own - while the
    /// place it changes still travels.
    func testAStatedSizeArrivesWhileThePlaceItMovesTravels() {
        let layout = HandWoundLayout()
        let grown = Placed()
        let below = Placed()
        layout.arrange([(grown, 1, Self.row(0)), (below, 2, Self.row(1))])

        layout.arrange([
            (grown, 1, Self.row(0, height: 80)),
            (below, 2, Rect(x: 0, y: 80, width: 100, height: 60)),
        ], heights: [1: 80, 2: 60])

        XCTAssertEqual(grown.placedFrame, Self.row(0, height: 80), "the stated height arrives")
        XCTAssertEqual(below.placedFrame, Rect(x: 0, y: 40, width: 100, height: 60), "the child below sets out")

        layout.frame(at: 100)
        XCTAssertEqual(below.placedFrame.y, 60, accuracy: 1e-9, "and travels to its new place")
        XCTAssertEqual(below.placedFrame.height, 60, "at the height it states")
    }

    /// A layout told to move nothing places its children at once, and a child that joins it is simply there.
    func testALayoutToldToMoveNothingPlacesAtOnce() {
        let layout = HandWoundLayout(motion: HostLayoutMotion(motion: .none, lanes: .all))
        let moved = Placed()
        layout.arrange([(moved, 1, Self.row(1))])

        layout.arrange([(moved, 1, Self.row(0)), (Placed(), 2, Self.row(1))])

        XCTAssertEqual(moved.placedFrame, Self.row(0))
        XCTAssertEqual(layout.fades, [:])
        XCTAssertFalse(layout.animator.isMoving)
    }

    /// A layout that says nothing of its own, or that inherits, travels the way the application says.
    func testALayoutThatSaysNothingTravelsTheApplicationsWay() {
        for said in [nil, HostLayoutMotion(motion: .inherited, lanes: .all)] {
            let layout = HandWoundLayout(motion: said)
            layout.motion.applicationMotion = .eased(200, .linear)
            let moved = Placed()
            layout.arrange([(moved, 1, Self.row(1))])

            layout.arrange([(moved, 1, Self.row(0))])
            layout.frame(at: 100)

            XCTAssertEqual(moved.placedFrame.y, 20, accuracy: 1e-9, "on the application's law: \(String(describing: said))")
        }
    }

    /// The same place asked for again - an arrangement with nothing new - keeps the animation under way rather
    /// than starting it over.
    func testTheSamePlaceAskedForAgainKeepsItsAnimation() {
        let layout = HandWoundLayout()
        let moved = Placed()
        layout.arrange([(moved, 1, Self.row(1))])
        layout.arrange([(moved, 1, Self.row(0))])
        layout.frame(at: 100)

        layout.arrange([(moved, 1, Self.row(0))], patched: false)
        XCTAssertEqual(moved.placedFrame.y, 20, accuracy: 1e-9, "it stays where it has reached")

        layout.frame(at: 150)
        XCTAssertEqual(moved.placedFrame.y, 10, accuracy: 1e-9, "on the same way, at the same time")
    }

    /// A place that changes mid-animation bends the animation from where the child stands, at the speed it has,
    /// rather than starting it again from where it was going.
    func testAPlaceChangedMidAnimationBendsFromWhereTheChildStands() throws {
        let layout = HandWoundLayout()
        let moved = Placed()
        layout.arrange([(moved, 1, Self.row(0))])
        layout.arrange([(moved, 1, Self.row(0, y: 100))])
        layout.frame(at: 100)
        XCTAssertEqual(moved.placedFrame.y, 50, accuracy: 1e-9)

        layout.arrange([(moved, 1, Self.row(0, y: 200))])
        XCTAssertEqual(moved.placedFrame.y, 50, accuracy: 1e-9, "it bends from where it stands")
        let bent = try XCTUnwrap(layout.animator.animation(for: .placed(1)))
        XCTAssertEqual(bent.velocity[1], 0.5, accuracy: 1e-9, "at the speed it has")

        layout.frame(at: 150)
        XCTAssertGreaterThan(moved.placedFrame.y, 50, "and goes on, never back")
        XCTAssertLessThan(moved.placedFrame.y, 200)

        layout.frame(at: 300)
        XCTAssertEqual(moved.placedFrame, Self.row(0, y: 200))
        XCTAssertFalse(layout.animator.isMoving)
    }

    /// A child that leaves takes its animation with it: nothing moves a place for an element the tree no longer
    /// holds.
    func testAChildThatLeavesEndsItsAnimation() {
        let layout = HandWoundLayout()
        let moved = Placed()
        layout.arrange([(moved, 1, Self.row(0))])
        layout.arrange([(moved, 1, Self.row(0, y: 100))])
        layout.frame(at: 100)

        layout.motion.remove(mount: 1)
        layout.frame(at: 150)

        XCTAssertFalse(layout.animator.isMoving)
        XCTAssertEqual(moved.placedFrame.y, 50, accuracy: 1e-9, "it is moved no more")
    }

    /// The place of a 100 x 40 row: the `index`th down a stack unless `y` says where.
    private static func row(_ index: Int, x: Double = 0, y: Double? = nil, height: Double = 40) -> Rect {
        Rect(x: x, y: y ?? Double(index) * 40, width: 100, height: height)
    }
}

/// A view that stands where it is placed.
@MainActor
private final class Placed: PlacedView {
    var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
}

/// One layout on a hand-wound clock: its arrangements, each after a patch unless it says otherwise, and its frames.
@MainActor
private final class HandWoundLayout {
    let animator = Animator()
    let places = TravellingPlaces()
    private(set) var motion: LayoutMotion!
    var reducesMotion = false

    /// The children that joined fading in, and the law each fades under.
    private(set) var fades: [UInt64: Motion] = [:]

    private var now = 0.0

    /// A layout whose patches say `motion`: 200 ms on a linear law, every side of a place.
    init(motion said: HostLayoutMotion? = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)) {
        motion = LayoutMotion(
            animator: animator, now: { [unowned self] in self.now },
            reducesMotion: { [unowned self] in self.reducesMotion })
        places.layoutMotion = motion
        places.motion = said
    }

    /// An arrangement `width` wide, after a patch where `patched`; every child states its width of 100, and the
    /// heights `heights` gives by mount.
    func arrange(
        _ children: [(view: Placed, mount: UInt64, place: Rect)],
        width: Double = 300,
        patched: Bool = true,
        heights: [UInt64: Double] = [:]
    ) {
        if patched { places.patchArrived() }
        places.begin(width: width)
        for child in children {
            var values = LayoutValues()
            values.width = 100
            values.height = heights[child.mount]
            places.place(child.view, mount: child.mount, at: child.place, values: values) { [unowned self] law in
                self.fades[child.mount] = law
            }
        }
    }

    /// A display frame at `time`.
    func frame(at time: Double) {
        now = time
        motion.follow(animator.advance(to: time, reducesMotion: reducesMotion))
    }
}
