// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

@MainActor
final class GTKCanvasViewTests: XCTestCase {
    /// Words at the start of their box stand at its left, words read right to left too: a canvas draws in its own
    /// coordinates.
    func testWordsAtABoxsStartStandAtItsLeft() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                Canvas {
                    Draw.textColor(.red)
                    Draw.text("ممممم", x: 0, y: 0, width: 200, height: 20)
                }
                .width(200).height(20).horizontalAlignment(.start)
            }
            let canvas = try XCTUnwrap(host.views(GTKCanvasView.self).first)
            @MainActor func inked(from left: Double) -> Bool {
                let points = stride(from: 2.0, to: 20, by: 2).flatMap { y in
                    stride(from: left, to: left + 100, by: 1).map { ($0, y) }
                }
                return canvas.pixels(at: points).contains { $0 >> 24 > 0 }
            }
            host.settle { inked(from: 0) || inked(from: 100) }

            XCTAssertTrue(inked(from: 0), "at the left")
            XCTAssertFalse(inked(from: 100), "nothing at the right")
        }
    }
}
