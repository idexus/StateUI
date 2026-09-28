// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// The runtime's one animator: every animation advanced together, in target order.
final class AnimatorTests: XCTestCase {
    /// One advance moves every animation, states first by number and then described
    /// properties by element and property - the order two runs of one frame
    /// both write in.
    @MainActor
    func testAnAdvanceMovesEveryAnimationInTargetOrder() {
        let animator = Animator()
        let near = DescribedKey(mount: 1, property: .opacity)
        let far = DescribedKey(mount: 2, property: .opacity)
        let animation = Animation(
            from: [0], destination: [1], velocity: [0], motion: .eased(200, .linear), began: 0)

        for target in [AnimationTarget.described(far), .state(5), .described(near), .state(1)] {
            animator.start(animation, for: target)
        }

        XCTAssertEqual(
            animator.advance(to: 100).map(\.target),
            [.state(1), .state(5), .described(near), .described(far)])
    }

    /// An animation runs until it arrives, and then it is gone: the animator
    /// holds nothing that no longer moves.
    @MainActor
    func testAnAnimationThatArrivesLeavesTheAnimator() {
        let animator = Animator()
        animator.start(
            Animation(from: [0], destination: [1], velocity: [0], motion: .eased(200, .linear), began: 0),
            for: .state(1))

        let halfway = animator.advance(to: 100)
        XCTAssertEqual(halfway.first?.value.first ?? .nan, 0.5, accuracy: 1e-9)
        XCTAssertEqual(halfway.first?.rested, false)
        XCTAssertTrue(animator.isMoving)

        let landed = animator.advance(to: 200)
        XCTAssertEqual(landed.first?.value, [1])
        XCTAssertEqual(landed.first?.rested, true)
        XCTAssertFalse(animator.isMoving)
        XCTAssertTrue(animator.advance(to: 300).isEmpty)
    }

    /// When the user asks for less movement, every animation lands at once, at
    /// its destination.
    @MainActor
    func testLessMovementLandsEveryAnimationAtOnce() {
        let animator = Animator()
        animator.start(
            Animation(from: [0], destination: [1], velocity: [0], motion: .spring(response: 300), began: 0),
            for: .state(1))
        animator.start(
            Animation(from: [5, 5], destination: [9, 1], velocity: [0, 0], motion: .eased(400), began: 0),
            for: .state(2))

        let steps = animator.advance(to: 10, reducesMotion: true)

        XCTAssertEqual(steps.map(\.value), [[1], [9, 1]])
        XCTAssertTrue(steps.allSatisfy(\.rested))
        XCTAssertFalse(animator.isMoving)
    }
}
