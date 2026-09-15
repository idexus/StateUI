// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitWalkerTests: XCTestCase {
    /// One walker walks every value: no other file of the host samples a
    /// motion law, so a state channel and a described property cannot walk
    /// the same kind of value two ways.
    func testOnlyTheWalkerSamplesALaw() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // StateUI.AppKit
            .appendingPathComponent("Sources")
        var found: [String] = []

        let names = try FileManager.default.contentsOfDirectory(atPath: sources.path).sorted()
        for name in names where name.hasSuffix(".swift") && name != "AppKitWalker.swift" {
            let text = try String(contentsOf: sources.appendingPathComponent(name), encoding: .utf8)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)

            for (number, line) in lines.enumerated()
            where line.contains("HostMotionLaw.sample(")
                && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                found.append("\(name):\(number + 1)")
            }
        }

        XCTAssertEqual(found, [], "a value is walked by AppKitWalker alone")
    }

    /// One step walks every trip, states first by number and then described
    /// properties by element and property - the order two runs of one frame
    /// both write in.
    @MainActor
    func testAStepWalksEveryTripInTargetOrder() {
        let walker = AppKitWalker()
        let near = AppKitDescribedKey(mount: 1, property: .opacity)
        let far = AppKitDescribedKey(mount: 2, property: .opacity)
        let trip = AppKitTrip(
            from: [0], destination: [1], velocity: [0], motion: .eased(200, .linear), began: 0)

        for target in [AppKitTripTarget.described(far), .state(5), .described(near), .state(1)] {
            walker.start(trip, for: target)
        }

        XCTAssertEqual(
            walker.step(now: 100).map(\.target),
            [.state(1), .state(5), .described(near), .described(far)])
    }

    /// A trip is walked until it arrives, and then it is gone: the walker
    /// holds nothing that no longer moves.
    @MainActor
    func testATripThatArrivesLeavesTheWalker() {
        let walker = AppKitWalker()
        walker.start(
            AppKitTrip(
                from: [0], destination: [1], velocity: [0], motion: .eased(200, .linear), began: 0),
            for: .state(1))

        let halfway = walker.step(now: 100)
        XCTAssertEqual(halfway.first?.value.first ?? .nan, 0.5, accuracy: 1e-9)
        XCTAssertEqual(halfway.first?.rested, false)
        XCTAssertTrue(walker.isMoving)

        let landed = walker.step(now: 200)
        XCTAssertEqual(landed.first?.value, [1])
        XCTAssertEqual(landed.first?.rested, true)
        XCTAssertFalse(walker.isMoving)
        XCTAssertTrue(walker.step(now: 300).isEmpty)
    }

    /// When the reader asks for less movement, every trip lands at once, at
    /// its destination.
    @MainActor
    func testLessMovementLandsEveryTripAtOnce() {
        let walker = AppKitWalker()
        walker.start(
            AppKitTrip(
                from: [0], destination: [1], velocity: [0], motion: .spring(response: 300), began: 0),
            for: .state(1))
        walker.start(
            AppKitTrip(
                from: [5, 5], destination: [9, 1], velocity: [0, 0], motion: .eased(400), began: 0),
            for: .state(2))

        let steps = walker.step(now: 10, reducesMotion: true)

        XCTAssertEqual(steps.map(\.value), [[1], [9, 1]])
        XCTAssertTrue(steps.allSatisfy(\.rested))
        XCTAssertFalse(walker.isMoving)
    }
}
#endif
