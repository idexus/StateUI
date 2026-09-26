// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// The transitions a patch describes: a value moves only within one shape,
/// and lands exactly.
final class DescribedMotionTests: XCTestCase {
    @MainActor
    func testAStructuredBrushMovesOnlyInsideItsStableShape() throws {
        let animator = Animator()
        let described = DescribedMotion(animator: animator)
        let key = DescribedKey(mount: 1, property: .fill)
        let source = HostValue.values([
            .enumeration(2),
            .numbers([0, 0, 1, 0]),
            .number(0), .color(red: 0, green: 0, blue: 0, alpha: 255),
            .number(1), .color(red: 255, green: 255, blue: 255, alpha: 255),
        ])
        let target = HostValue.values([
            .enumeration(2),
            .numbers([0, 1, 1, 1]),
            .number(0.2), .color(red: 255, green: 0, blue: 0, alpha: 255),
            .number(0.8), .color(red: 0, green: 0, blue: 255, alpha: 255),
        ])

        described.receive(
            key: key,
            standing: source,
            target: target,
            motion: .eased(200, .linear),
            now: 0,
            reducesMotion: false)
        XCTAssertEqual(described.presentedValue(for: key), source)

        described.follow(animator.advance(to: 100))
        XCTAssertEqual(described.takeOutputs().last?.value, .values([
            .enumeration(2),
            .numbers([0, 0.5, 1, 0.5]),
            .number(0.1), .color(red: 128, green: 0, blue: 0, alpha: 255),
            .number(0.9), .color(red: 128, green: 128, blue: 255, alpha: 255),
        ]))
    }

    @MainActor
    func testChangingAStructuredBrushShapeSnapsInsteadOfInventingAnIntermediate() {
        let animator = Animator()
        let described = DescribedMotion(animator: animator)
        let key = DescribedKey(mount: 1, property: .fill)
        let linear = HostValue.values([
            .enumeration(2),
            .numbers([0, 0, 1, 1]),
            .number(0), .color(red: 0, green: 0, blue: 0, alpha: 255),
        ])
        let solid = HostValue.values([
            .enumeration(1),
            .color(red: 255, green: 255, blue: 255, alpha: 255),
        ])

        described.receive(
            key: key,
            standing: linear,
            target: solid,
            motion: .eased(200, .linear),
            now: 0,
            reducesMotion: false)

        XCTAssertNil(described.presentedValue(for: key))
        XCTAssertFalse(described.isActive)
    }

    /// `background` is one property whichever it carries: two colours on it
    /// move as colours, and a colour never blends into a brush.
    @MainActor
    func testAColourBackgroundMovesAsAColourAndSnapsToABrush() {
        let animator = Animator()
        let described = DescribedMotion(animator: animator)
        let colour = DescribedKey(mount: 1, property: .background)
        let black = HostValue.color(red: 0, green: 0, blue: 0, alpha: 255)

        described.receive(
            key: colour,
            standing: black,
            target: .color(red: 255, green: 255, blue: 255, alpha: 255),
            motion: .eased(200, .linear),
            now: 0,
            reducesMotion: false)

        described.follow(animator.advance(to: 100))
        XCTAssertEqual(described.takeOutputs().last?.value,
                       .color(red: 128, green: 128, blue: 128, alpha: 255))

        let brush = DescribedKey(mount: 2, property: .background)
        described.receive(
            key: brush,
            standing: black,
            target: .values([.enumeration(1), .color(red: 255, green: 0, blue: 0, alpha: 255)]),
            motion: .eased(200, .linear),
            now: 100,
            reducesMotion: false)

        XCTAssertNil(described.presentedValue(for: brush))
    }

    /// A property sent somewhere new mid-animation starts again from where it stands, at the speed it has; the
    /// animation it cut short ends once, there, and the new one lands exactly where it was sent.
    @MainActor
    func testARetargetedPropertyBendsFromWhereItStandsAndLandsItsFirstOnce() throws {
        let animator = Animator()
        let described = DescribedMotion(animator: animator)
        let key = DescribedKey(mount: 1, property: .opacity)
        var firstEnded = 0
        var secondEnded = 0
        described.receive(
            key: key, standing: .number(0), target: .number(1), motion: .eased(200, .linear),
            landed: { firstEnded += 1 }, now: 0, reducesMotion: false)
        described.follow(animator.advance(to: 100))
        _ = described.takeOutputs()

        described.receive(
            key: key, standing: .number(1), target: .number(0), motion: .eased(200, .linear),
            landed: { secondEnded += 1 }, now: 100, reducesMotion: false)

        XCTAssertEqual(described.presentedValue(for: key), .number(0.5), "it bends from where it stands")
        let bent = try XCTUnwrap(animator.animation(for: .described(key)))
        XCTAssertEqual(bent.velocity[0], 0.005, accuracy: 1e-9, "at the speed it had")
        XCTAssertEqual(firstEnded, 1, "the animation cut short ends there")
        XCTAssertEqual(secondEnded, 0)

        described.follow(animator.advance(to: 300))
        XCTAssertEqual(described.takeOutputs().last?.value, .number(0), "and lands exactly where it was sent")
        XCTAssertFalse(described.isActive)
        described.follow(animator.advance(to: 400))
        XCTAssertEqual([firstEnded, secondEnded], [1, 1], "each ends once")
    }

    /// An element that leaves takes its animations with it: none of its properties is drawn again, not even a frame
    /// drawn before it left, while another element's animations go on.
    @MainActor
    func testALeavingElementsAnimationsEndAndDrawNothingMore() {
        let animator = Animator()
        let described = DescribedMotion(animator: animator)
        let fading = DescribedKey(mount: 1, property: .opacity)
        let turning = DescribedKey(mount: 1, property: .rotation)
        let staying = DescribedKey(mount: 2, property: .opacity)
        for key in [fading, turning, staying] {
            described.receive(
                key: key, standing: .number(0), target: .number(1), motion: .eased(200, .linear),
                now: 0, reducesMotion: false)
        }
        let channel = Animation(from: [0], destination: [1], velocity: [0], motion: .eased(200, .linear), began: 0)
        animator.start(channel, for: .state(1))
        described.follow(animator.advance(to: 50))

        described.remove(mount: 1)

        XCTAssertEqual(described.takeOutputs().map(\.key), [staying], "the frame drawn before it left is not drawn")
        XCTAssertNil(described.presentedValue(for: fading))
        XCTAssertNil(described.presentedValue(for: turning))
        XCTAssertNil(animator.animation(for: .described(fading)))
        XCTAssertNotNil(animator.animation(for: .state(1)), "what is not the element's goes on")

        described.follow(animator.advance(to: 100))
        XCTAssertEqual(described.takeOutputs().map(\.key), [staying])
        described.follow(animator.advance(to: 200))
        XCTAssertEqual(described.takeOutputs().map(\.key), [staying])
        XCTAssertFalse(described.isActive)
    }
}
