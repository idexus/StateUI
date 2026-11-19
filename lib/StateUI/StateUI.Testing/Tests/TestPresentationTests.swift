// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
@testable import StateUITesting
import XCTest

/// What a view presents is read where a movement has got it to, by the view itself or by an id kept from before.
@MainActor
final class TestPresentationTests: XCTestCase {
    /// Half-way through a movement the presentation is half-way: moved, turned, scaled and faded as the host layer
    /// worked it out, while the states already hold where they are going.
    func testAPresentationIsWhereAMovementHasGotTo() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { CardPage() }
        let card = try window.element("card")
        let still = try card.presentation()
        XCTAssertEqual(still.translation, Point(x: 0, y: 0))
        XCTAssertEqual([still.opacity, still.scaleX, still.scaleY, still.rotation], [1, 1, 1, 0])

        try window.element("card.send").send(.activate)
        try await clock.advance(by: .milliseconds(100))

        let moving = try card.presentation()
        XCTAssertEqual(moving.translation.x, 50, accuracy: 0.01)
        XCTAssertEqual(moving.translation.y, 0)
        XCTAssertEqual(moving.opacity, 0.75, accuracy: 0.001)
        XCTAssertEqual(moving.scaleX, 1.5, accuracy: 0.001, "`scale` over `scaleX`")
        XCTAssertEqual(moving.scaleY, 1.5, accuracy: 0.001)
        XCTAssertEqual(moving.rotation, 45, accuracy: 0.01)
        XCTAssertEqual(moving.id, still.id)
        XCTAssertEqual(moving.generation, still.generation, "the same mounting, moved")
        try await window.close()
    }

    /// A view takes input while nothing over it is disabled and it ignores none, and says how assistive technology
    /// meets it only where the page said.
    func testAPresentationSaysItsPartInInputAndAccessibility() async throws {
        let window = try await TestWindow(motion: .none) { PartsPage() }

        XCTAssertTrue(try window.element("parts.plain").presentation().takesInput)
        XCTAssertNil(try window.element("parts.plain").presentation().accessibilityPresence)
        XCTAssertFalse(try window.element("parts.ignoring").presentation().takesInput)
        XCTAssertFalse(try window.element("parts.inDisabled").presentation().takesInput, "its branch is disabled")
        XCTAssertEqual(try window.element("parts.hidden").presentation().accessibilityPresence, .hidden)
        try await window.close()
    }

    /// An id kept from before names the view while it stands; taken off the page it presents nothing, and a view
    /// the page names with `.id(_:)` shown again is another mounting of the same view.
    func testAnIdKeptNamesTheViewWhileItStands() async throws {
        let window = try await TestWindow(motion: .none) { ComingPage() }
        let first = try window.element("coming.card").presentation()
        XCTAssertEqual(window.presentation(first.id), first)

        try await window.element("coming.turn").perform(.toggle)
        XCTAssertNil(window.presentation(first.id), "taken off the page")
        XCTAssertThrowsError(try window.element("coming.card"))

        try await window.element("coming.turn").perform(.toggle)
        let second = try XCTUnwrap(window.presentation(first.id))
        XCTAssertEqual(second.id, first.id)
        XCTAssertNotEqual(second.generation, first.generation, "shown again, another mounting")

        try await window.close()
        XCTAssertNil(window.presentation(first.id), "a closed window presents nothing")
    }
}

/// A card a button sends across, turns, scales and fades over 200 milliseconds, linearly.
private struct CardPage: View {
    @State private var across = 0.0
    @State private var turn = 0.0
    @State private var size = 1.0
    @State private var fade = 1.0

    var body: some View {
        VStack {
            Rectangle()
                .translationX($across)
                .rotation($turn)
                .scale($size)
                .opacity($fade)
                .accessibilityIdentifier("card")
            Button("Send")
                .accessibilityIdentifier("card.send")
                .onClicked {
                    let motion = Motion.eased(.milliseconds(200), curve: .linear)
                    $across.journey.move(to: 100, motion)
                    $turn.journey.move(to: 90, motion)
                    $size.journey.move(to: 2, motion)
                    $fade.journey.move(to: 0.5, motion)
                }
        }
    }
}

/// Views taking input and not, and one assistive technology skips.
private struct PartsPage: View {
    var body: some View {
        VStack {
            Text("Plain").accessibilityIdentifier("parts.plain")
            Text("Ignoring").ignoresInput(true).accessibilityIdentifier("parts.ignoring")
            VStack {
                Text("In a disabled branch").accessibilityIdentifier("parts.inDisabled")
            }
            .isEnabled(false)
            Text("Hidden").accessibilityPresence(.hidden).accessibilityIdentifier("parts.hidden")
        }
    }
}

/// A card a switch takes off the page and shows again.
private struct ComingPage: View {
    @State private var shown = true

    var body: some View {
        VStack {
            if shown {
                Text("Card").id("card").accessibilityIdentifier("coming.card")
            }
            Switch($shown).accessibilityIdentifier("coming.turn")
        }
    }
}
