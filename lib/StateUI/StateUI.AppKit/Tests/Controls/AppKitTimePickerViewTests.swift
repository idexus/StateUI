// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

final class AppKitTimePickerViewTests: XCTestCase {
    /// A time is an hour and a minute: the field keeps no second it does not show.
    @MainActor
    func testATimeIsAnHourAndAMinute() {
        let picker = AppKitTimePickerView()

        picker.setTime(ClockTime(hour: 21, minute: 5, second: 30))

        XCTAssertEqual(picker.time, ClockTime(hour: 21, minute: 5))
        XCTAssertEqual(picker.datePickerElements, .hourMinute)
    }

    /// A time past the day stands in the next, added up from midnight.
    @MainActor
    func testATimePastTheDayStandsInTheNext() {
        let picker = AppKitTimePickerView()

        picker.setTime(ClockTime(hour: 25, minute: 99))

        XCTAssertEqual(picker.time, ClockTime(hour: 2, minute: 39))
    }

    /// The time a user picks reaches the page's `onTimeChanged`.
    @MainActor
    func testATimeTheUserPicksReachesTheTimeHandler() throws {
        let times = Received<ClockTime>()
        let renderer = AppKitRenderer.running {
            TimePicker(ClockTime(hour: 7, minute: 30))
                .onTimeChanged { times.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitTimePickerView.self).first)

        picker.chooseForTesting(ClockTime(hour: 21, minute: 5))

        XCTAssertEqual(times.values, [ClockTime(hour: 21, minute: 5)])
    }
}

#endif
