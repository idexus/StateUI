// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import StateUI
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

    /// AN ICON IS DRAWN WITHIN ITS OWN CELL, however large the room makes it: a press is taken by the icon drawn
    /// under it, and a neighbour drawn over the cell would take it instead.
    @MainActor
    func testAnIconIsDrawnWithinItsOwnCell() {
        for room in [Rect(0, 0, 390, 700), Rect(0, 0, 1400, 1000), Rect(0, 0, 600, 300)] {
            let fit = Fit.of(room)
            let (width, height) = ((room.width - 16) / Double(fit.columns), (room.height - 16) / Double(fit.rows))
            let scale = min(width / 84, height / 96)
            for slot in 0..<fit.perBoard {
                let placed = HomeScreenSample.place(slot, 0, room, fit)
                let cell = Rect(8 + Double(slot % fit.columns) * width, 8 + Double(slot / fit.columns) * height,
                                width, height)
                XCTAssertEqual(placed.transform, .scale(scale), "larger as far as the cell lets it")
                let (across, down) = (placed.bounds.width * scale, placed.bounds.height * scale)
                let drawn = Rect(placed.bounds.x + (placed.bounds.width - across) / 2,
                                 placed.bounds.y + (placed.bounds.height - down) / 2, across, down)
                XCTAssertTrue(
                    drawn.x >= cell.x - 1e-9 && drawn.y >= cell.y - 1e-9
                        && drawn.x + drawn.width <= cell.x + cell.width + 1e-9
                        && drawn.y + drawn.height <= cell.y + cell.height + 1e-9,
                    "slot \(slot) of \(room): drawn \(drawn), its cell \(cell)")
            }
        }
    }
}
