// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The transitions a patch describes: a value moves only within one shape,
/// and lands exactly.
final class DescribedMotionTests: XCTestCase {
    @MainActor
    func testAStructuredBrushMovesOnlyInsideItsStableShape() throws {
        let walker = Walker()
        let described = DescribedMotion(walker: walker)
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

        described.follow(walker.step(now: 100))
        XCTAssertEqual(described.takeOutputs().last?.value, .values([
            .enumeration(2),
            .numbers([0, 0.5, 1, 0.5]),
            .number(0.1), .color(red: 128, green: 0, blue: 0, alpha: 255),
            .number(0.9), .color(red: 128, green: 128, blue: 255, alpha: 255),
        ]))
    }

    @MainActor
    func testChangingAStructuredBrushShapeSnapsInsteadOfInventingAnIntermediate() {
        let walker = Walker()
        let described = DescribedMotion(walker: walker)
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
        let walker = Walker()
        let described = DescribedMotion(walker: walker)
        let colour = DescribedKey(mount: 1, property: .background)
        let black = HostValue.color(red: 0, green: 0, blue: 0, alpha: 255)

        described.receive(
            key: colour,
            standing: black,
            target: .color(red: 255, green: 255, blue: 255, alpha: 255),
            motion: .eased(200, .linear),
            now: 0,
            reducesMotion: false)

        described.follow(walker.step(now: 100))
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
}
