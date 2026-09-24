// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUISliderViewTests: XCTestCase {
    func testASliderShowsItsRangeAndItsValue() throws {
        try onUIThread {
            let level = State(wrappedValue: 2.5)
            let host = WinUIRenderer.running { VStack { Slider(level.projectedValue).minimum(0).maximum(10) } }
            let slider = try XCTUnwrap(host.views(WinUISliderView.self).first)

            XCTAssertEqual(slider.minimum, 0)
            XCTAssertEqual(slider.maximum, 10)
            XCTAssertEqual(slider.value, 2.5, accuracy: 1e-9)
        }
    }

    /// A new range leaves the thumb's value alone, kept inside the range.
    func testARangeTheTreeChangesKeepsTheThumbsValue() throws {
        try onUIThread {
            let top = State(wrappedValue: 10.0)
            let level = State(wrappedValue: 4.0)
            let host = WinUIRenderer.running {
                VStack {
                    Slider(level.projectedValue).minimum(0).maximum(top.wrappedValue)
                    Button("Narrow").onClicked { top.wrappedValue = 8 }
                }
            }
            let slider = try XCTUnwrap(host.views(WinUISliderView.self).first)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()

            XCTAssertEqual(slider.maximum, 8)
            XCTAssertEqual(slider.value, 4, accuracy: 1e-9)
        }
    }

    /// The state a button writes travels to the thumb on the display's frames, and none of them is heard as the user's.
    func testAStateWriteIsNotHeardAsTheUsers() throws {
        try onUIThread {
            let clock = TestClock()
            let level = State(wrappedValue: 0.25)
            let heard = Received<Double>()
            let host = WinUIRenderer.running(clock: clock) {
                VStack {
                    Slider(level.projectedValue).onValueChanged { heard.values.append($0) }
                    Button("Full").onClicked { level.wrappedValue = 1 }
                }
            }
            let slider = try XCTUnwrap(host.views(WinUISliderView.self).first)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            for time in stride(from: 16.0, through: 2_000, by: 16) {
                clock.now = time
                host.frame()
            }

            XCTAssertEqual(slider.value, 1, accuracy: 1e-9)
            XCTAssertEqual(heard.values, [])
        }
    }

    /// The user's move reaches both halves: the journey takes the value, and the handler hears it.
    func testAUsersMoveTakesTheJourneyAndIsHeard() throws {
        try onUIThread {
            let level = State(wrappedValue: 0.0)
            let moves = Received<Double>()
            let host = WinUIRenderer.running {
                VStack {
                    Label("level \(level.wrappedValue)")
                    Slider(level.projectedValue).onValueChanged { moves.values.append($0) }
                }
            }
            let slider = try XCTUnwrap(host.views(WinUISliderView.self).first)

            slider.move(to: 0.75)

            XCTAssertEqual(level.wrappedValue, 0.75, accuracy: 1e-9, "the journey took the thumb's value")
            XCTAssertEqual(moves.values, [0.75], "and the handler heard it once")
            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["level 0.75"])
            XCTAssertEqual(slider.value, 0.75, accuracy: 1e-9, "the render left the thumb where the hand put it")
        }
    }
}
