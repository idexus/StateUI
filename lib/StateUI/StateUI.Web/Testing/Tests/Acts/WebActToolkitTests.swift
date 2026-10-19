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

    /// A launch opens a page's address, mail's, a call's or the relay's own file - read as the browser reads an
    /// address, its spaces, controls, tabs and line breaks dropped - and never one that runs a script in the
    /// application's origin.
    func testALaunchOpensNoScript() {
        for address in [
            "https://example.com", "http://example.com/a", "mailto:a@example.com", "tel:+48123456789",
            "blob:https://example.com/0f1e", "HTTPS://EXAMPLE.COM",
        ] {
            XCTAssertTrue(WebFileToolkit.launches(address), address)
        }
        for address in [
            "javascript:alert(1)", "JaVaScRiPt:alert(1)", " javascript:alert(1)", "java\tscript:alert(1)",
            "java\nscript:alert(1)", "\u{1}javascript:alert(1)", "data:text/html,<script>alert(1)</script>",
            "vbscript:msgbox(1)", "file:///etc/passwd", "example.com", "", ":",
        ] {
            XCTAssertFalse(WebFileToolkit.launches(address), address.debugDescription)
        }
    }

    /// The local time of day stands within its day, and the local zone has a name.
    func testTheLocalTimeStandsWithinItsDay() {
        let now = WebRelay.localTime
        XCTAssertTrue((0..<24).contains(now.hour) && (0..<60).contains(now.minute) && (0..<60).contains(now.second))
        XCTAssertTrue((0..<1000).contains(now.millisecond))
        XCTAssertFalse(WebRelay.localZone.isEmpty)
    }
}
