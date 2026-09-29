// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import StateUIConformance
import XCTest

final class WinUIInputViewTests: XCTestCase {
    /// A placeholder in a colour of its own stands where the words do: in the middle of a field whose words stand
    /// centred. A search box's template stands its own at the start, in the theme's colour (`WinUIRealization`).
    func testAColouredPlaceholderStandsWhereTheWordsDo() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    TextField(State(wrappedValue: "").projectedValue)
                        .placeholder("MMMM")
                        .placeholderColor(Color(red: 255, green: 0, blue: 0))
                        .horizontalTextAlignment(.center)
                        .width(300)
                }
            }
            host.layOut()

            let field = try XCTUnwrap(host.views(WinUITextFieldView.self).first)
            let ink = try XCTUnwrap(Self.redInk(in: field), "the placeholder drawn red")
            XCTAssertTrue((100.0...200.0).contains((ink.lowerBound + ink.upperBound) / 2), "it stands at \(ink)")
        }
    }

    /// Where a view draws red across its middle, in DIPs from its leading edge; nil for nowhere.
    @MainActor
    private static func redInk(in view: WinUIView) -> ClosedRange<Double>? {
        let frame = view.frame
        let points = stride(from: 0.0, to: frame.width, by: 1).flatMap { x in
            [-2.0, 0, 2].map { dy in (x, frame.height / 2 + dy) }
        }
        let red = zip(points, view.pixels(at: points)).filter { _, argb in
            (argb >> 16) & 0xFF > 150 && (argb >> 8) & 0xFF < 100 && argb & 0xFF < 100
        }.map(\.0.0)
        guard let first = red.min(), let last = red.max() else { return nil }
        return first...last
    }
}
