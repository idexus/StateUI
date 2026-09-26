// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidSliderViewTests: XCTestCase {
    static var allTests: [(String, (AndroidSliderViewTests) -> () throws -> Void)] {
        [
            ("testASliderShowsItsRangeAndItsValue", testASliderShowsItsRangeAndItsValue),
            ("testARangeTheTreeChangesKeepsTheThumbsValue", testARangeTheTreeChangesKeepsTheThumbsValue),
            ("testAStateWriteIsNotHeardAsTheUsers", testAStateWriteIsNotHeardAsTheUsers),
            ("testAUsersDragTakesTheJourneyAndIsHeard", testAUsersDragTakesTheJourneyAndIsHeard),
        ]
    }

    func testASliderShowsItsRangeAndItsValue() throws {
        try onMainActor {
            let level = State(wrappedValue: 2.5)
            let host = AndroidRenderer.running { VStack { Slider(level.projectedValue).minimum(0).maximum(10) } }
            let slider = try XCTUnwrap(host.views(AndroidSliderView.self).first)

            XCTAssertEqual(slider.minimum, 0)
            XCTAssertEqual(slider.maximum, 10)
            XCTAssertEqual(slider.value, 2.5, accuracy: 1e-9)
        }
    }

    /// A new range leaves the thumb's value alone, kept inside the range.
    func testARangeTheTreeChangesKeepsTheThumbsValue() throws {
        try onMainActor {
            let top = State(wrappedValue: 10.0)
            let level = State(wrappedValue: 4.0)
            let host = AndroidRenderer.running {
                VStack {
                    Slider(level.projectedValue).minimum(0).maximum(top.wrappedValue)
                    Button("Narrow").onClicked { top.wrappedValue = 8 }
                }
            }
            let slider = try XCTUnwrap(host.views(AndroidSliderView.self).first)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()

            XCTAssertEqual(slider.maximum, 8)
            XCTAssertEqual(slider.value, 4, accuracy: 1e-9)
        }
    }

    /// The state a button writes travels to the thumb on the display's frames, and none of them is heard as the user's.
    func testAStateWriteIsNotHeardAsTheUsers() throws {
        try onMainActor {
            let clock = TestClock()
            let level = State(wrappedValue: 0.25)
            let heard = Received<Double>()
            let host = AndroidRenderer.running(clock: clock) {
                VStack {
                    Slider(level.projectedValue).onValueChanged { heard.values.append($0) }
                    Button("Full").onClicked { level.wrappedValue = 1 }
                }
            }
            let slider = try XCTUnwrap(host.views(AndroidSliderView.self).first)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            for time in stride(from: 16.0, through: 2_000, by: 16) {
                clock.now = time
                host.frame()
            }

            XCTAssertEqual(slider.value, 1, accuracy: 1e-9)
            XCTAssertEqual(heard.values, [])
        }
    }

    /// A drag reaches both halves: the journey takes the value the hand left, and the handlers hear it.
    func testAUsersDragTakesTheJourneyAndIsHeard() throws {
        try onMainActor {
            let level = State(wrappedValue: 0.0)
            let moves = Received<Double>()
            let drags = Received<String>()
            let host = AndroidRenderer.running {
                VStack {
                    Slider(level.projectedValue)
                        .onValueChanged { moves.values.append($0) }
                        .onDragStarted { drags.values.append("started") }
                        .onDragCompleted { drags.values.append("completed") }
                }
            }
            host.layOut()
            let slider = try XCTUnwrap(host.views(AndroidSliderView.self).first)

            slider.drag(from: 0.2, to: 0.75)

            XCTAssertEqual(drags.values, ["started", "completed"])
            XCTAssertGreaterThan(slider.value, 0.6)
            XCTAssertEqual(level.wrappedValue, slider.value, accuracy: 1e-9, "the journey took the thumb's value")
            XCTAssertEqual(moves.values.last ?? -1, slider.value, accuracy: 1e-9, "and the handler heard it")
        }
    }
}
