// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import StateUI
import StateUITesting
import XCTest

/// The Semantics sample used as a screen-reader user uses it, through a test's window: the rating stepped and
/// cleared by the reader's own acts.
@MainActor
final class SemanticsSampleTests: XCTestCase {
    func testAReaderStepsTheRatingAndClearsIt() async throws {
        let window = try await TestWindow(motion: .none) { SemanticsSample() }
        let rating = try window.element("semantics.rating")
        XCTAssertEqual(rating.value(VisualElementContract.accessibilityValue), "3 of 5")

        try await rating.perform(.adjust(.increment))
        XCTAssertEqual(rating.value(VisualElementContract.accessibilityValue), "4 of 5")

        try await rating.perform(.performAccessibilityAction("Clear"))
        XCTAssertEqual(rating.value(VisualElementContract.accessibilityValue), "0 of 5")
    }
}
