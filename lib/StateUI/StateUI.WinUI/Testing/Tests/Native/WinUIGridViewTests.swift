// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUIGridViewTests: XCTestCase {
    /// Words with a margin in a cell are measured at the cell's width less the margin, once: on one line, as tall
    /// as without it, and the pass settles.
    func testWordsWithAMarginStandOnOneLineInTheirCell() {
        onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Grid { Text("Waiting for the first render of this scene") }
                    Grid { Text("Waiting for the first render of this scene").margin(horizontal: 8, vertical: 4) }
                }
                .horizontalAlignment(.start)
            }
            let labels = host.views(WinUITextView.self)
            XCTAssertEqual(labels.count, 2)
            XCTAssertEqual(labels[1].frame.height, labels[0].frame.height, "on one line")
            XCTAssertEqual(labels[1].frame.y, 4)
        }
    }

    /// Words wrapping in one of two proportional columns settle in one pass: the grid offered less than its natural
    /// width wraps them, and so it does as its window narrows from wide, step by step.
    func testWordsWrapInOneOfTwoProportionalColumns() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Text("One line")
                    VStack {
                        Grid {
                            Text("2026-10-02 17:03")
                            Text("Korekta").gridColumn(1)
                            Text("Anna Zając (5)").gridColumn(2)
                            Text("Wadliwa: Uszkodzona (było: Czeka na decyzję)").gridColumn(3)
                        }
                        .columns(.fixed(140), .fixed(130), .proportional(2), .proportional(3))
                        .columnSpacing(12)
                    }
                    .padding(horizontal: 14, vertical: 12)
                }
                .padding(horizontal: 24, vertical: 20)
            }
            let labels = host.views(WinUITextView.self)
            let words = try XCTUnwrap(labels.last)
            let line = labels[0].frame.height
            XCTAssertGreaterThan(words.frame.height, line * 1.5, "wrapped")

            let window = try XCTUnwrap(host.window)
            for width in stride(from: 1400.0, through: 480, by: -23) {
                window.request(WindowFrame(width: width, height: 440))
                host.step()
                host.layOut()
            }
            XCTAssertGreaterThan(words.frame.height, line * 1.5, "wrapped again")
        }
    }
}
