// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// What an element shows of a layout program's answers: each child at its place, a change setting a child out from
/// where it was shown, a moving place carrying a child that follows it, and the bodies stepped to rest.
/// Design: docs/design/host/layout.md#bodies
final class ProgramPresentationTests: XCTestCase {
    private let spring = LayoutBody.onChange(response: .milliseconds(160))
    private let follower = LayoutBody.followsLayout(response: .milliseconds(160))

    /// A child `x` across, ten points square, at `opacity`.
    private func place(_ x: Double, opacity: Double = 1) -> HostPlacement {
        HostPlacement(
            bounds: Rect(x: x, y: 0, width: 10, height: 10), translationX: 0, translationY: 0, rotation: 0, scaleX: 1,
            scaleY: 1, opacity: opacity, zIndex: 0, shade: HostPlacement.unshaded)
    }

    /// An answer of the children `views` names, of the change numbered `change`.
    private func answer(_ views: [HostLayoutView], change: UInt64 = 0) -> HostLayoutAnswer {
        HostLayoutAnswer(views: views, change: change)
    }

    /// THE FIRST ANSWER SHOWS THE LAYOUT AS IT STANDS: nothing was shown for a change to set out from, whatever
    /// change the answer names.
    func testTheFirstAnswerSetsNothingOut() {
        var shown = ProgramPresentation()

        let placed = shown.take(
            answer([HostLayoutView(key: 1, target: place(0), body: spring, discrete: place(50))], change: 7), at: 0,
            reducesMotion: false)

        XCTAssertEqual(placed, [place(0)])
        XCTAssertFalse(shown.moves)
    }

    /// A CHANGE SETS A CHILD OUT FROM WHERE IT WAS SHOWN: at the change it stands where it stood, then comes onto
    /// its place on its body's spring, and is a body no more once there.
    func testAChangeSetsAChildOutFromWhereItWasShown() {
        var shown = ProgramPresentation()
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(100), body: spring)]), at: 0, reducesMotion: false)

        let changed = answer([HostLayoutView(key: 1, target: place(0), body: spring, discrete: place(0))], change: 1)
        XCTAssertEqual(shown.take(changed, at: 16, reducesMotion: false)[0].bounds.x, 100, accuracy: 0.001)
        XCTAssertTrue(shown.moves)

        let going = shown.step(to: 96)[0].bounds.x
        XCTAssertLessThan(going, 100, "on its way")
        XCTAssertGreaterThan(going, 0)

        var last = going
        for frame in 7...200 {
            guard shown.moves else { break }
            last = shown.step(to: Double(frame) * 16)[0].bounds.x
        }
        XCTAssertEqual(last, 0, accuracy: 0.001, "at its place")
        XCTAssertFalse(shown.moves, "and a body no more")
    }

    /// A CHANGE READ AGAIN SETS OUT ONCE: the same answer taken a second time moves nothing anew.
    func testAChangeReadTwiceSetsOutOnce() {
        var shown = ProgramPresentation()
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(100), body: spring)]), at: 0, reducesMotion: false)
        let changed = answer([HostLayoutView(key: 1, target: place(0), body: spring, discrete: place(0))], change: 1)
        _ = shown.take(changed, at: 16, reducesMotion: false)
        let going = shown.step(to: 96)[0].bounds.x

        let again = shown.take(changed, at: 96, reducesMotion: false)[0].bounds.x

        XCTAssertEqual(again, going, accuracy: 0.001, "where it had got to, not where it set out")
    }

    /// A CHILD NEVER SHOWN JOINS FROM NOTHING: at its place, its opacity from nought.
    func testAChildJoiningFadesIn() {
        var shown = ProgramPresentation()
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(0), body: spring)]), at: 0, reducesMotion: false)

        let joined = answer([
            HostLayoutView(key: 1, target: place(0), body: spring),
            HostLayoutView(key: 2, target: place(100, opacity: 0.8), body: spring, discrete: place(100, opacity: 0.8)),
        ], change: 1)
        let placed = shown.take(joined, at: 16, reducesMotion: false)

        XCTAssertEqual(placed[1].bounds.x, 100, "where its layout puts it")
        XCTAssertEqual(placed[1].opacity, 0, accuracy: 0.001, "from nothing")
        XCTAssertEqual(placed[0], place(0), "the child the change moves nowhere stands")
    }

    /// A CHILD THAT SAYS NO BODY OF ITS OWN IS ITS LAYOUT'S: a spring answering a change where the layout says
    /// nothing, what the layout says where it does - and a child's own word wins over it either way.
    func testAChildIsItsOwnBodyElseItsLayouts() {
        func firstFrame(_ own: LayoutBody?, layout: LayoutBody?) -> Double {
            var shown = ProgramPresentation()
            let bodies = layout ?? .onChange()
            _ = shown.take(
                answer([HostLayoutView(key: 1, target: place(100), body: own)]), layoutBodies: bodies, at: 0,
                reducesMotion: false)
            let changed = answer([HostLayoutView(key: 1, target: place(0), body: own, discrete: place(0))], change: 1)
            return shown.take(changed, layoutBodies: bodies, at: 16, reducesMotion: false)[0].bounds.x
        }

        XCTAssertEqual(firstFrame(nil, layout: nil), 100, "nothing said: a body answering the change")
        XCTAssertEqual(firstFrame(nil, layout: LayoutBody.none), 0, "the layout's none: at its place at once")
        XCTAssertEqual(firstFrame(spring, layout: LayoutBody.none), 100, "its own body in a layout of none")
        XCTAssertEqual(firstFrame(LayoutBody.none, layout: spring), 0, "its own none among bodies")
    }

    /// A CHILD OF NO BODY, AND EVERY CHILD UNDER LESS MOTION, STANDS AT ITS PLACE AT ONCE - one on its way too.
    func testNoBodyAndLessMotionLand() {
        var shown = ProgramPresentation()
        let none = LayoutBody.none
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(100), body: none)]), at: 0, reducesMotion: false)
        let bare = answer([HostLayoutView(key: 1, target: place(0), body: none, discrete: place(0))], change: 1)
        XCTAssertEqual(shown.take(bare, at: 16, reducesMotion: false), [place(0)], "no body")

        var reduced = ProgramPresentation()
        _ = reduced.take(answer([HostLayoutView(key: 1, target: place(100), body: spring)]), at: 0, reducesMotion: false)
        let changed = answer([HostLayoutView(key: 1, target: place(0), body: spring, discrete: place(0))], change: 1)
        _ = reduced.take(changed, at: 16, reducesMotion: false)
        XCTAssertTrue(reduced.moves)
        XCTAssertEqual(reduced.take(changed, at: 32, reducesMotion: true), [place(0)], "less motion asked for on its way")
        XCTAssertFalse(reduced.moves)
    }

    /// A CHILD FOLLOWING ITS PLACE IS CARRIED BY ITS PLACE'S MOVE; one answering a change alone goes with its place.
    func testOnlyAFollowingChildLagsBehindAMovingPlace() {
        var shown = ProgramPresentation()
        _ = shown.take(
            answer([
                HostLayoutView(key: 1, target: place(0), body: follower), HostLayoutView(key: 2, target: place(0), body: spring),
            ]), at: 0, reducesMotion: false)

        let moved = shown.take(
            answer([
                HostLayoutView(key: 1, target: place(100), body: follower),
                HostLayoutView(key: 2, target: place(100), body: spring),
            ]), at: 16, reducesMotion: false)

        XCTAssertLessThan(moved[0].bounds.x, 50, "behind its place as it leaps")
        XCTAssertEqual(moved[1].bounds.x, 100, accuracy: 0.001, "with its place")
        XCTAssertTrue(shown.moves)
    }

    /// A FOLLOWING CHILD DAMPED BELOW ONE PASSES ITS PLACE AND SETTLES ONTO IT.
    func testALighterDampedFollowerPassesItsPlaceAndSettles() {
        let swaying = LayoutBody.followsLayout(response: .milliseconds(400), damping: 0.5)
        var shown = ProgramPresentation()
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(0), body: swaying)]), at: 0, reducesMotion: false)
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(100), body: swaying)]), at: 16, reducesMotion: false)

        var (farthest, last) = (0.0, 0.0)
        for frame in 2...400 {
            guard shown.moves else { break }
            last = shown.step(to: Double(frame) * 16)[0].bounds.x
            farthest = max(farthest, last)
        }

        XCTAssertGreaterThan(farthest, 101, "past it")
        XCTAssertEqual(last, 100, accuracy: 0.01, "onto it")
        XCTAssertFalse(shown.moves)
    }

    /// A CHILD THE HAND LET GO SETS OUT AT THE HAND'S SPEED, from where the hand held it; held, it stood exactly
    /// there, whatever its body.
    func testAChildLetGoSetsOutAtTheHandsSpeed() {
        var shown = ProgramPresentation()
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(0), body: spring)]), at: 0, reducesMotion: false)
        var hand = LocalPresentation()
        hand.held = Point(x: 60, y: 0)
        XCTAssertEqual(shown.step(to: 16, locals: [hand]).map(\.bounds.x), [60], "where the hand holds it")
        XCTAssertFalse(shown.moves)

        hand.held = nil
        hand.letGo = Point(x: 2_000, y: 0)
        XCTAssertEqual(shown.step(to: 32, locals: [hand])[0].bounds.x, 60, accuracy: 0.001)
        XCTAssertGreaterThan(
            shown.step(to: 48, locals: [hand])[0].bounds.x, 60, "carried on by the hand's speed before it turns back")
    }

    /// A HELD CHILD IS RANKED OVER EVERY OTHER HOWEVER HIGH THEY STAND - the highest rank an integer holds, several
    /// alike - and the others keep their order beneath it.
    func testAHeldChildIsRankedOverChildrenAtTheHighestRank() {
        func ranked(_ x: Double, _ rank: Int) -> HostPlacement { place(x).ranked(rank) }
        var shown = ProgramPresentation()
        let layout = answer([
            HostLayoutView(key: 1, target: ranked(0, .max)), HostLayoutView(key: 2, target: ranked(50, .max)),
            HostLayoutView(key: 3, target: ranked(200, .max - 1)),
        ])
        _ = shown.take(layout, at: 0, reducesMotion: false)
        var hand = LocalPresentation()
        hand.held = Point(x: 10, y: 0)

        let held = shown.step(to: 16, locals: [hand, LocalPresentation(), LocalPresentation()])

        XCTAssertEqual(held.map(\.zIndex), [2, 1, 0], "the first held over the second, the second over the third as they stood")
    }

    /// A HELD CHILD WEARS ITS PLACE'S LOOK WHERE THE HAND HOLDS IT: the layout may lift it meanwhile - larger - and
    /// it stays under the hand.
    func testAHeldChildWearsItsPlacesLookWhereTheHandHoldsIt() {
        func lifted(_ scale: Double) -> HostPlacement {
            HostPlacement(
                bounds: Rect(x: 50, y: 0, width: 100, height: 100), translationX: 0, translationY: 0, rotation: 0,
                scaleX: scale, scaleY: scale, opacity: 1, zIndex: 0, shade: HostPlacement.unshaded)
        }
        var shown = ProgramPresentation()
        _ = shown.take(answer([HostLayoutView(key: 1, target: lifted(1))]), at: 0, reducesMotion: false)
        var hand = LocalPresentation()
        hand.held = Point(x: 30, y: 40)
        _ = shown.step(to: 16, locals: [hand])

        let held = shown.take(answer([HostLayoutView(key: 1, target: lifted(1.2))]), locals: [hand], at: 32, reducesMotion: false)

        XCTAssertEqual(held[0].scaleX, 1.2, "lifted as its place says")
        XCTAssertEqual(held[0].bounds, Rect(x: 80, y: 40, width: 100, height: 100), "under the hand")
    }

    /// A CHILD GONE FROM THE ANSWER IS FORGOTTEN: come again, it joins from nothing.
    func testAChildGoneIsForgotten() {
        var shown = ProgramPresentation()
        _ = shown.take(answer([HostLayoutView(key: 1, target: place(0), body: spring)]), at: 0, reducesMotion: false)
        _ = shown.take(answer([], change: 1), at: 16, reducesMotion: false)

        let back = shown.take(
            answer([HostLayoutView(key: 1, target: place(0), body: spring, discrete: place(0))], change: 2), at: 32,
            reducesMotion: false)

        XCTAssertEqual(back[0].opacity, 0, accuracy: 0.001)
    }
}
