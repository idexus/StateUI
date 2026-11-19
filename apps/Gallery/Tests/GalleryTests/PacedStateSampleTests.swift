// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import StateUI
import StateUITesting
import XCTest

/// The cadence sample used as its user uses it: the box faded, its three counts read.
@MainActor
final class PacedStateSampleTests: XCTestCase {
    /// While the box fades and samples are taken, the converted words are built once: a sample builds the words
    /// counting it and nothing beside them.
    func testTheConvertedWordsStandAtOneBuildWhileSamplesAreTaken() async throws {
        let window = try await TestWindow { PacedStateSample() }

        try await window.element("paced.fade").perform(.activate)

        XCTAssertNotEqual(try window.element("paced.taken").value(TextElementContract.text), "0 samples taken")
        XCTAssertEqual(
            try window.element("paced.converted.builds").value(TextElementContract.text), "1 build, first time")
    }
}
