// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@testable import StateUITesting
import XCTest

/// A press in phases - down, dragged, let go or taken away - on a clock the test winds: a pan with the speed the
/// clock gives its moves, a movement interrupted half-way, and a press let go where it went down.
@MainActor
final class PressTests: XCTestCase {
    /// Down, two moves ten milliseconds apart and a lift: the pan begins with the first move, says how far it came
    /// and ends at the hand's speed - twenty points every hundredth of a second.
    func testAPressDraggedIsAPanAtTheSpeedTheClockGives() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { PanPage() }
        let box = try window.element("pan.box")
        let said = try window.element("pan.said")

        try box.send(.pressDown(at: Point(x: 10, y: 10)))
        try await window.flush()
        XCTAssertEqual(try said.value(TextElementContract.text), "", "a press alone is no pan yet")

        try await clock.advance(by: .milliseconds(10))
        try box.send(.drag(to: Point(x: 30, y: 10)))
        try await clock.advance(by: .milliseconds(10))
        try box.send(.drag(to: Point(x: 50, y: 10)))
        try await window.flush()
        XCTAssertEqual(try said.value(TextElementContract.text), "began changed 20 changed 40")

        try await clock.advance(by: .milliseconds(10))
        try box.send(.lift)
        try await window.flush()
        XCTAssertEqual(try said.value(TextElementContract.text), "began changed 20 changed 40 ended 40")
        let speed = try XCTUnwrap(Double(try XCTUnwrap(window.element("pan.speed").value(TextElementContract.text))))
        XCTAssertEqual(speed, 2_000, accuracy: 700, "some 20 points every 10 milliseconds, as the clock said")
        XCTAssertEqual(clock.now, .milliseconds(30))
        try await window.close()
    }

    /// A box on its way for 400 milliseconds, taken by the hand half-way: its movement ends superseded, the box
    /// follows the hand from where it stood, and the press taken away puts it back there - all at the clock's time.
    func testAMovementIsInterruptedHalfWayByAPanAndThePanCancelled() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { ThrownPage() }
        let box = try window.element("thrown.box")
        let said = try window.element("thrown.said")

        try window.element("thrown.go").send(.activate)
        try await clock.advance(by: .milliseconds(200))
        XCTAssertEqual(try XCTUnwrap(box.value(VisualElementContract.translationX)), 100, accuracy: 0.5)

        try box.send(.pressDown(at: Point(x: 5, y: 5)))
        try box.send(.drag(to: Point(x: 35, y: 5)))
        try await window.flush()
        XCTAssertEqual(try said.value(TextElementContract.text), "superseded")
        XCTAssertEqual(try XCTUnwrap(box.value(VisualElementContract.translationX)), 130, accuracy: 0.5)

        try box.send(.cancelInteraction)
        try await window.flush()
        XCTAssertEqual(try said.value(TextElementContract.text), "cancelled")
        XCTAssertEqual(try XCTUnwrap(box.value(VisualElementContract.translationX)), 100, accuracy: 0.5)

        try await clock.advance(by: .milliseconds(400))
        XCTAssertEqual(try XCTUnwrap(box.value(VisualElementContract.translationX)), 100, accuracy: 0.5, "it stays")
        XCTAssertEqual(clock.now, .milliseconds(600))
        try await window.close()
    }

    /// A press let go where it went down is the view's tap, and a button's click; one dragged is neither.
    func testAPressLetGoWhereItWentDownIsATapOrAClick() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { TapPage() }
        let said = try window.element("tap.said")

        for view in ["tap.words", "tap.button"] {
            try window.element(view).send(.pressDown(at: Point(x: 4, y: 4)))
            try window.element(view).send(.lift)
        }
        try await window.flush()
        XCTAssertEqual(try said.value(TextElementContract.text), "tapped clicked")

        try window.element("tap.both").send(.pressDown(at: Point(x: 4, y: 4)))
        try window.element("tap.both").send(.drag(to: Point(x: 40, y: 4)))
        try window.element("tap.both").send(.lift)
        try await window.flush()
        XCTAssertEqual(try said.value(TextElementContract.text), "tapped clicked", "a press dragged is no tap")
        try await window.close()
    }

    /// One press at a time, and a move or a lift only of a press that went down on that view.
    func testAPressIsOneAndItsMovesAreItsOwn() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { TapPage() }
        let words = try window.element("tap.words")

        XCTAssertThrowsError(try words.send(.drag(to: Point(x: 9, y: 9))), "no press went down")
        XCTAssertThrowsError(try words.send(.lift))
        XCTAssertThrowsError(try words.send(.cancelInteraction))
        XCTAssertThrowsError(try window.element("tap.said").send(.pressDown(at: .zero)), "it listens for no press")

        try words.send(.pressDown(at: Point(x: 4, y: 4)))
        XCTAssertThrowsError(try window.element("tap.button").send(.pressDown(at: .zero)), "a press is under way")
        XCTAssertThrowsError(try window.element("tap.button").send(.lift), "the press is another view's")
        try words.send(.cancelInteraction)
        try await window.flush()
        XCTAssertEqual(try window.element("tap.said").value(TextElementContract.text), "", "taken away, it tapped nothing")
        try await window.close()
    }
}

/// A box saying each report of the pan over it and, as it ends, how fast the hand went.
private struct PanPage: View {
    @State private var said: [String] = []
    @State private var speed = ""

    var body: some View {
        VStack {
            Rectangle()
                .onPanUpdated { update in
                    said.append(update.phase == .began ? "began" : "\(update.phase) \(Int(update.total.x))")
                    if update.phase == .ended { speed = "\(update.velocity.x)" }
                }
                .accessibilityIdentifier("pan.box")
            Text(said.joined(separator: " ")).accessibilityIdentifier("pan.said")
            Text(speed).accessibilityIdentifier("pan.speed")
        }
    }
}

/// A box a button sends 200 points across in 400 milliseconds; a pan takes it from where it stands, and a pan taken
/// away puts it back where the hand took it.
private struct ThrownPage: View {
    @State private var x = 0.0
    @State private var taken = 0.0
    @State private var said = ""

    var body: some View {
        VStack {
            Rectangle()
                .translationX($x)
                .onPanUpdated { update in
                    switch update.phase {
                    case .began: taken = $x.journey.sample?.value ?? x
                    case .changed: $x.journey.snap(to: taken + update.total.x)
                    case .cancelled:
                        $x.journey.snap(to: taken)
                        said = "cancelled"
                    default: break
                    }
                }
                .accessibilityIdentifier("thrown.box")
            Text(said).accessibilityIdentifier("thrown.said")
            Button("Go")
                .accessibilityIdentifier("thrown.go")
                .onClicked(policy: .ignoreWhileRunning) {
                    let result = try await $x.journey.move(to: 200, .eased(.milliseconds(400), curve: .linear)).result()
                    said = "\(result)"
                }
        }
    }
}

/// Words that hear a tap, a button, and words that hear a tap and a pan.
private struct TapPage: View {
    @State private var said: [String] = []

    var body: some View {
        VStack {
            Text("Words").onTapped { said.append("tapped") }.accessibilityIdentifier("tap.words")
            Button("Button").onClicked { said.append("clicked") }.accessibilityIdentifier("tap.button")
            Text("Both")
                .onTapped { said.append("tapped both") }
                .onPanUpdated { _ in }
                .accessibilityIdentifier("tap.both")
            Text(said.joined(separator: " ")).accessibilityIdentifier("tap.said")
        }
    }
}
