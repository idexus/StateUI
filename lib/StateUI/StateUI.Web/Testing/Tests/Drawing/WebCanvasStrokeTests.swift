// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A canvas's drawing as the relay replays it: what the pen holds reaches each operation, and a state put back
/// with none saved does nothing.
@MainActor
final class WebCanvasStrokeTests: XCTestCase {
    private func stroke(_ instructions: [CanvasInstruction]) -> WebCanvasStroke {
        WebCanvasStroke(instructions)
    }

    /// A rectangle filled in the pen's color at the pen's opacity: its path, then the fill.
    func testAFillTakesThePensColorAtItsOpacity() {
        let drawn = stroke([
            .fillColor(.color(red: 255, green: 0, blue: 0, alpha: 255)), .opacity(0.5),
            .fillRectangle(Rect(x: 0, y: 0, width: 10, height: 20)),
        ])
        XCTAssertEqual(Array(drawn.numbers.prefix(4)), [5, 6, 0, 0], "a path begins at the corner")
        XCTAssertEqual(Array(drawn.numbers.suffix(6)), [10, 11, 255, 0, 0, 0.5])
    }

    /// The states saved are put back in turn; one more put back has nothing to put back.
    func testARestoreWithNothingSavedDoesNothing() {
        let drawn = stroke([.saveState, .translate(x: 4, y: 2), .restoreState, .restoreState])
        XCTAssertEqual(drawn.numbers, [0, 2, 4, 2, 1])
    }

    /// Words go by their place among the drawing's words, with their room, their size and the height of their lines,
    /// their color, the edge they stand at and its point across, and their alignment down.
    func testWordsAreWrittenByTheirPlace() {
        let drawn = stroke([
            .fontSize(20), .text("42", in: Rect(x: 1, y: 2, width: 30, height: 14), horizontal: .center, vertical: .start),
        ])
        XCTAssertEqual(drawn.words, ["42"])
        XCTAssertEqual(drawn.numbers, [13, 0, 1, 2, 30, 14, 20, 28, 0, 0, 0, 1, 1, 16, 0])
    }

    /// Words written before the drawing sets a size stand at the body's, and a size of nought stays nought; the end
    /// of a box is its right whichever way the page reads.
    func testWordsStandAtTheBodysSizeAtTheEdgeTheirBoxSays() {
        let room = Rect(x: 0, y: 0, width: 40, height: 10)
        let drawn = stroke([
            .text("a", in: room, horizontal: .end, vertical: .end),
            .fontSize(0), .text("b", in: room, horizontal: .start, vertical: .center),
        ])
        XCTAssertEqual(drawn.numbers, [
            13, 0, 0, 0, 40, 10, 15, 21, 0, 0, 0, 1, 2, 40, 2,
            13, 1, 0, 0, 40, 10, 0, 0, 0, 0, 0, 1, 0, 0, 1,
        ])
    }
}
