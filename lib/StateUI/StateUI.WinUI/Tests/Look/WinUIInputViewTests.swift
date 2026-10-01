// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import StateUIConformance
import XCTest

final class WinUIInputViewTests: XCTestCase {
    /// A search box draws its placeholder in a colour of its own, through the theme resources its template reads,
    /// and in a new one written later with no theme read again; the template stands it at the start
    /// (`WinUIRealization`).
    func testASearchBoxDrawsItsPlaceholderInItsColour() throws {
        try onUIThread {
            let colour = State(wrappedValue: Color(red: 255, green: 0, blue: 0))
            let host = WinUIRenderer.running {
                VStack {
                    SearchField(State(wrappedValue: "").projectedValue)
                        .placeholder("MMMM")
                        .placeholderColor(colour.wrappedValue)
                        .width(300)
                }
            }
            host.layOut()

            let search = try XCTUnwrap(host.views(WinUISearchFieldView.self).first)
            XCTAssertNotNil(Self.ink(in: search, of: Self.isRed), "the placeholder drawn red")
            let read = stateui_winui_themes_read_again()

            colour.wrappedValue = Color(red: 0, green: 0, blue: 255)
            host.settle { Self.ink(in: search, of: Self.isBlue) != nil }
            XCTAssertNotNil(Self.ink(in: search, of: Self.isBlue), "the placeholder drawn blue")
            XCTAssertEqual(stateui_winui_themes_read_again(), read, "the theme read again")
        }
    }

    /// A placeholder in a colour of its own stands where the words do: in the middle of a field whose words stand
    /// centred.
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
            let ink = try XCTUnwrap(Self.ink(in: field, of: Self.isRed), "the placeholder drawn red")
            XCTAssertTrue((100.0...200.0).contains((ink.lowerBound + ink.upperBound) / 2), "it stands at \(ink)")
        }
    }

    private static func isRed(_ argb: UInt32) -> Bool {
        (argb >> 16) & 0xFF > 150 && (argb >> 8) & 0xFF < 100 && argb & 0xFF < 100
    }

    private static func isBlue(_ argb: UInt32) -> Bool {
        (argb >> 16) & 0xFF < 100 && (argb >> 8) & 0xFF < 100 && argb & 0xFF > 150
    }

    /// Where a view draws in a colour `matches` across its middle, in DIPs from its leading edge; nil for nowhere.
    @MainActor
    private static func ink(in view: WinUIView, of matches: (UInt32) -> Bool) -> ClosedRange<Double>? {
        let frame = view.frame
        let points = stride(from: 0.0, to: frame.width, by: 1).flatMap { x in
            [-2.0, 0, 2].map { dy in (x, frame.height / 2 + dy) }
        }
        let drawn = zip(points, view.pixels(at: points)).filter { matches($1) }.map(\.0.0)
        guard let first = drawn.min(), let last = drawn.max() else { return nil }
        return first...last
    }
}
