// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import XCTest

/// The home screen's boards as the room changes their grid.
final class HomeScreenSampleTests: XCTestCase {
    private typealias Fit = HomeScreenSample.Fit

    /// A NEW GRID SHOWS THE ICONS THE BOARD IN FRONT SHOWED: the board of it that holds most of them - the first of
    /// two that hold as many - so a turned phone keeps its place among the icons.
    func testANewGridShowsTheIconsTheBoardInFrontShowed() {
        let (tall, wide) = (Fit(columns: 4, rows: 5), Fit(columns: 5, rows: 3))

        XCTAssertEqual(wide.board(showing: 1, of: tall, count: 48), 1, "20-39: ten on 15-29, ten on 30-44 - the first")
        XCTAssertEqual(wide.board(showing: 2, of: tall, count: 48), 2, "40-47: five on 30-44, three on 45-47")
        XCTAssertEqual(tall.board(showing: 2, of: wide, count: 48), 1, "30-44: ten on 20-39, five on 40-47")
        XCTAssertEqual(tall.board(showing: 3, of: wide, count: 48), 2, "45-47, all on 40-47")
        XCTAssertEqual(wide.board(showing: 0, of: tall, count: 48), 0)
    }
}
