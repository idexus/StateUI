// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import StateUI
import StateUITesting
import XCTest

/// The engine sample's two engines used as its user uses them: a tap, the words' engine turned first, a tap again.
@MainActor
final class EngineOrderSampleTests: XCTestCase {
    /// The words see the count this tap wrote while their engine runs second, and the count before it once a render
    /// turned their priority first.
    func testTheWordsSeeTheCountOnlyRunningAfterIt() async throws {
        let window = try await TestWindow(motion: .none) { EngineOrder() }
        let (counted, seen) = (try window.element("engine.counted"), try window.element("engine.seen"))

        try await window.element("engine.tap").perform(.activate)
        XCTAssertEqual(try counted.value(TextElementContract.text), "Counted 1")
        XCTAssertEqual(try seen.value(TextElementContract.text), "Words saw 1")

        try await window.element("engine.words.first").perform(.toggle)
        try await window.element("engine.tap").perform(.activate)
        XCTAssertEqual(try counted.value(TextElementContract.text), "Counted 2")
        XCTAssertEqual(try seen.value(TextElementContract.text), "Words saw 1")
    }
}
