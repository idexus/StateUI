// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@testable import StateUITesting
import XCTest

/// A window a test's clock winds: its page mounts at the clock's time, an act is sent with no waiting, and a
/// movement travels only as far as the test advances the clock.
@MainActor
final class TestClockTests: XCTestCase {
    /// The page stands, and no time passed mounting it.
    func testAWindowWithAClockMountsMovingNoTime() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }

        XCTAssertEqual(clock.now, .zero)
        XCTAssertEqual(try window.element("fade.box").value(VisualElementContract.opacity), 1)
        try await window.close()
    }

    /// A movement of 200 milliseconds: sent and flushed it stands where it began; half the time on it is half-way;
    /// the rest lands it, and its handler hears it reached.
    func testAMovementTravelsOnlyAsTheClockAdvances() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }
        let box = try window.element("fade.box")

        try window.element("fade.go").send(.activate)
        try await window.flush()
        try await window.flush()
        XCTAssertEqual(clock.now, .zero, "a flush moves no time")
        XCTAssertEqual(try box.value(VisualElementContract.opacity), 1, "begun, and standing where it began")

        try await clock.advance(by: .milliseconds(100))
        XCTAssertEqual(try XCTUnwrap(box.value(VisualElementContract.opacity)), 0.5, accuracy: 0.001)
        XCTAssertEqual(try window.element("fade.said").value(TextElementContract.text), "moving")

        try await clock.advance(by: .milliseconds(100))
        XCTAssertEqual(try box.value(VisualElementContract.opacity), 0)
        XCTAssertEqual(try window.element("fade.said").value(TextElementContract.text), "reached")
        XCTAssertEqual(clock.now, .milliseconds(200))
        try await window.close()
    }

    /// Steps of ten milliseconds and a last, shorter one: 25 milliseconds on, an eighth of the way.
    func testAnAdvanceEndsOnAShorterStep() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }

        try window.element("fade.go").send(.activate)
        try await clock.advance(by: .milliseconds(25), step: .milliseconds(10))

        XCTAssertEqual(clock.now, .milliseconds(25))
        XCTAssertEqual(
            try XCTUnwrap(window.element("fade.box").value(VisualElementContract.opacity)), 0.875, accuracy: 0.001)
        try await window.close()
    }

    /// Stopped half-way with no wall time: the handler hears `.stopped`, and the box stays there however far the
    /// clock goes on.
    func testAMovementStoppedHalfWayStaysThere() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }
        let box = try window.element("fade.box")

        try window.element("fade.go").send(.activate)
        try await clock.advance(by: .milliseconds(100))
        try window.element("fade.stop").send(.activate)
        try await window.flush()

        XCTAssertEqual(try window.element("fade.said").value(TextElementContract.text), "stopped")
        try await clock.advance(by: .milliseconds(300))
        XCTAssertEqual(try XCTUnwrap(box.value(VisualElementContract.opacity)), 0.5, accuracy: 0.001)
        try await window.close()
    }

    /// A clock is never wound back, and its step is longer than nothing.
    func testAClockIsNotWoundBackNorByNoStep() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }

        await XCTAssertThrowsFailure { try await clock.advance(by: .milliseconds(-1)) }
        await XCTAssertThrowsFailure { try await clock.advance(by: .milliseconds(10), step: .zero) }
        try await clock.advance(by: .zero)
        XCTAssertEqual(clock.now, .zero)
        try await window.close()
    }

    /// One clock winds one window: a second on it is refused while the first stands, and taken once it closed.
    func testAClockWindsOneWindowAtATime() async throws {
        let clock = TestClock()
        let first = try await TestWindow(clock: clock) { FadingPage() }

        await XCTAssertThrowsFailure { _ = try await TestWindow(clock: clock) { FadingPage() } }
        XCTAssertNoThrow(try first.element("fade.box"), "the refused window closed nothing")

        try await first.close()
        let second = try await TestWindow(clock: clock) { FadingPage() }
        XCTAssertNoThrow(try second.element("fade.box"))
        try await second.close()
    }

    /// A closed window is wound no more; flushing it and closing it again do nothing.
    func testAnAdvanceAfterTheWindowClosedFails() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }
        try await window.close()

        await XCTAssertThrowsFailure { try await clock.advance(by: .milliseconds(10)) }
        try await window.flush()
        try await window.close()

        await XCTAssertThrowsFailure { try await TestClock().advance(by: .milliseconds(10)) }
    }

    /// Closing a window with a movement under way waits for no animation: the clock stands where the test left it.
    func testClosingSpeedsNoTimeUp() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }

        try window.element("fade.go").send(.activate)
        try await clock.advance(by: .milliseconds(50))
        try await window.close()

        XCTAssertEqual(clock.now, .milliseconds(50))
    }

    /// `perform` waits by running frames: in a window wound by hand it refuses, and names `send`.
    func testPerformRefusesInAWindowWoundByHand() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { FadingPage() }
        let go = try window.element("fade.go")

        do {
            try await go.perform(.activate)
            XCTFail("perform ran in a window wound by hand")
        } catch let failure as TestFailure {
            XCTAssertTrue(failure.description.contains("send(_:)"), failure.description)
        }
        XCTAssertEqual(try window.element("fade.said").value(TextElementContract.text), "still", "and did nothing")
        try await window.close()
    }

    /// An ordinary window sends too: the act lands at the next flush, with no second of frames run.
    func testAnOrdinaryWindowSendsAndFlushes() async throws {
        let window = try await TestWindow(motion: .none) { FadingPage() }

        try window.element("fade.stop").send(.activate)
        try await window.flush()

        XCTAssertNoThrow(try window.element("fade.box"))
        try await window.close()
    }
}

/// A box a button fades out over 200 milliseconds, linearly, another stops, and words saying how the fade ended.
private struct FadingPage: View {
    @State private var fade = 1.0
    @State private var said = "still"

    var body: some View {
        VStack {
            Rectangle()
                .opacity($fade)
                .accessibilityIdentifier("fade.box")
            Text(said)
                .accessibilityIdentifier("fade.said")
            Button("Go")
                .accessibilityIdentifier("fade.go")
                .onClicked(policy: .ignoreWhileRunning) {
                    said = "moving"
                    let result = try await $fade.journey.move(to: 0, .eased(.milliseconds(200), curve: .linear)).result()
                    said = result == .reached(.animated) ? "reached" : "\(result)"
                }
            Button("Stop")
                .accessibilityIdentifier("fade.stop")
                .onClicked { $fade.journey.stop() }
        }
    }
}

/// Fails unless `body` throws a `TestFailure`.
@MainActor
private func XCTAssertThrowsFailure(
    _ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line
) async {
    do {
        try await body()
        XCTFail("no failure was thrown", file: file, line: line)
    } catch is TestFailure {
    } catch {
        XCTFail("\(error) is no TestFailure", file: file, line: line)
    }
}
