// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A transition as it is declared and as it crosses: an effect's steps folded in the order written, the entry and
/// the exit as numbers and back, and the property on the element that declares it.
@MainActor
final class TransitionTests: XCTestCase {
    /// AN EFFECT'S STEPS FOLD IN THE ORDER WRITTEN: a move after a scale is not scaled, a scale after a move scales
    /// the move, moves add up, scales multiply, and fading is fading whatever stands beside it.
    func testAnEffectsStepsFoldInTheOrderWritten() {
        XCTAssertTrue(TransitionEffect.identity.host.isIdentity)
        XCTAssertEqual(TransitionEffect.opacity.host.opacity, 0)

        let scaledThenMoved = TransitionEffect.scale(0.5).combined(with: .translation(x: 20, y: 10)).host
        XCTAssertEqual(scaledThenMoved.scale, 0.5)
        XCTAssertEqual(scaledThenMoved.translation, Point(x: 20, y: 10), "written after the scale: as written")

        let movedThenScaled = TransitionEffect.translation(x: 20, y: 10).combined(with: .scale(0.5)).host
        XCTAssertEqual(movedThenScaled.translation, Point(x: 10, y: 5), "written before it: scaled with the view")

        let twice = TransitionEffect.translation(x: 4).combined(with: .translation(y: 6)).combined(with: .scale(2))
            .combined(with: .scale(2)).combined(with: .opacity)
        XCTAssertEqual(twice.host.translation, Point(x: 16, y: 24))
        XCTAssertEqual(twice.host.scale, 4)
        XCTAssertEqual(twice.host.opacity, 0)
    }

    /// A STEP THAT IS NO NUMBER IS NO STEP, and said.
    func testAStepThatIsNoNumberIsNoStep() {
        XCTAssertEqual(TransitionEffect.translation(x: .nan), .identity)
        XCTAssertEqual(TransitionEffect.scale(-1), .identity)
        XCTAssertEqual(TransitionEffect.scale(.infinity), .identity)
        XCTAssertTrue(hasComplained("A TransitionEffect's translation is no number"))
        XCTAssertTrue(hasComplained("A TransitionEffect's scale is no number of nought or more"))
    }

    /// A TRANSITION CROSSES AS ITS NUMBERS AND COMES BACK DRAWING THE SAME: the entry's four, the exit's four, and
    /// whether it enters as it first appears.
    func testATransitionCrossesAsItsNumbers() throws {
        let transition = Transition(
            enter: .opacity.combined(with: .translation(y: 12)), exit: .scale(0.8).combined(with: .translation(x: -6)))
        XCTAssertEqual(transition.propValue, .numbers([0, 0, 12, 1, 1, -6, 0, 0.8, 0]))

        let back = try XCTUnwrap(Transition(propValue: transition.propValue))
        XCTAssertEqual(back.host.enter, transition.host.enter)
        XCTAssertEqual(back.host.exit, transition.host.exit)
        XCTAssertFalse(back.host.entersInitially)

        let initially = try XCTUnwrap(Transition(propValue: transition.initialAppearance(true).propValue))
        XCTAssertTrue(initially.host.entersInitially)
        XCTAssertEqual(Transition.symmetric(.opacity).enter, Transition.symmetric(.opacity).exit)
        XCTAssertNil(Transition(propValue: .numbers([0, 0, 12])), "another run of numbers is none")
        XCTAssertNil(Transition(propValue: .numbers(Array(repeating: .nan, count: 9))))
    }

    /// THE ELEMENT THAT DECLARES A TRANSITION CARRIES IT IN ITS PATCH, and one that declares none carries nothing.
    func testTheElementCarriesItsTransition() throws {
        let transition = Transition.symmetric(.opacity.combined(with: .translation(y: 12)))
        let patch = Renders().render(VStack {
            Text("comes").transition(transition).id("comes")
            Text("stands").id("stands")
        }.node)

        let comes = try XCTUnwrap(patch.subtree.first { $0.id == .manual("comes") })
        let stands = try XCTUnwrap(patch.subtree.first { $0.id == .manual("stands") })
        XCTAssertEqual(comes.properties[.transition].flatMap(Transition.init(propValue:))?.host.enter, transition.host.enter)
        XCTAssertNil(stands.properties[.transition])
    }
}
