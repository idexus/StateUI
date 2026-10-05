// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// The clock and the zones as the browser has them, which the acts `currentTime`, `currentTimeZone` and `utcOffset`
/// answer from.
@MainActor
final class WebActToolkitTests: XCTestCase {
    /// A zone's offset is taken at the day's noon, so a day in summer and one in winter differ where the zone keeps
    /// summer time; a zone the browser does not know has none.
    func testAZonesOffsetIsItsOwnOnTheDayAsked() {
        let winter = CalendarDate(year: 2026, month: 1, day: 15)
        let summer = CalendarDate(year: 2026, month: 7, day: 15)
        XCTAssertEqual(WebRelay.utcOffset(of: "Europe/Warsaw", on: winter), 60)
        XCTAssertEqual(WebRelay.utcOffset(of: "Europe/Warsaw", on: summer), 120)
        XCTAssertEqual(WebRelay.utcOffset(of: "America/New_York", on: winter), -300)
        XCTAssertEqual(WebRelay.utcOffset(of: "Asia/Kolkata", on: summer), 330)
        XCTAssertEqual(WebRelay.utcOffset(of: "UTC", on: summer), 0)
        XCTAssertNil(WebRelay.utcOffset(of: "Nowhere/Land", on: summer))
    }

    /// The local time of day stands within its day, and the local zone has a name.
    func testTheLocalTimeStandsWithinItsDay() {
        let now = WebRelay.localTime
        XCTAssertTrue((0..<24).contains(now.hour) && (0..<60).contains(now.minute) && (0..<60).contains(now.second))
        XCTAssertTrue((0..<1000).contains(now.millisecond))
        XCTAssertFalse(WebRelay.localZone.isEmpty)
    }
}
