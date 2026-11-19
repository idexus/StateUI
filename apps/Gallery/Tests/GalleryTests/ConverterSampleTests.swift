// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import StateUI
import StateUITesting
import XCTest

/// The converters sample's last row used as its user uses it, on a clock wound by hand: two sources written in one
/// press, one result with a motion of its own.
@MainActor
final class ConverterSampleTests: XCTestCase {
    /// Both sources written at once work the result out once: the caption says where it is going at the press, and
    /// the bar makes one journey there on its own spring - on its way after a tenth of a second, there in the end.
    func testAResultTravelsUnderItsOwnMotionWhileItsCaptionSaysTheDestination() async throws {
        let clock = TestClock()
        let window = try await TestWindow(clock: clock) { ConverterSample() }
        let bar = try window.element("converters.bar")
        let going = try window.element("converters.going")
        XCTAssertEqual(try bar.value(VisualElementContract.width), 160)
        XCTAssertEqual(try going.value(TextElementContract.text), "going to 160")

        try window.element("converters.both").send(.activate)
        try await window.flush()
        XCTAssertEqual(try going.value(TextElementContract.text), "going to 300", "the destination, at once")
        XCTAssertEqual(try bar.value(VisualElementContract.width), 160, "the bar has not set out before a frame")

        try await clock.advance(by: .milliseconds(100))
        let onTheWay = try XCTUnwrap(bar.value(VisualElementContract.width))
        XCTAssertGreaterThan(onTheWay, 160)
        XCTAssertLessThan(onTheWay, 300, "one journey under way, not a jump")

        try await clock.advance(by: .seconds(2))
        XCTAssertEqual(try XCTUnwrap(bar.value(VisualElementContract.width)), 300, accuracy: 0.01)
        try await window.close()
    }
}
