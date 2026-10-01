// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit

/// The locale and the battery the host reports are the Mac's own, each told to the core in one report.
final class AppKitEnvironmentTests: XCTestCase {
    /// The locale report is the user's locale, its zone and its language's direction.
    @MainActor
    func testTheLocaleReportedIsTheUsers() {
        let locale = StandardEnvironment.locale
        let before = HostLocaleInfo(
            language: locale.language, region: locale.region, name: locale.name, timeZone: locale.timeZone,
            uses24HourClock: locale.uses24HourClock, firstDayOfWeek: locale.firstDayOfWeek,
            isMetric: locale.isMetric, layoutDirection: locale.layoutDirection)
        defer { HostBoundary.setLocaleInfo(before) }
        locale.name = ""
        locale.layoutDirection = .rightToLeft

        AppKitEnvironment(core: CoreLink()).reportLocale()

        XCTAssertEqual(locale.name, Locale.current.identifier(.bcp47))
        XCTAssertEqual(locale.language, Locale.current.language.languageCode?.identifier ?? "")
        XCTAssertEqual(locale.timeZone, TimeZone.current.identifier)
        XCTAssertEqual(
            locale.layoutDirection,
            Locale.current.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
    }

    /// The battery report says something settled: a level from 0 to 1 and a state, `notPresent` on a Mac with none.
    @MainActor
    func testTheBatteryReportedIsSettled() {
        let battery = StandardEnvironment.battery
        let before = HostBatteryInfo(
            chargeLevel: battery.chargeLevel, state: battery.state, powerSource: battery.powerSource,
            energySaverStatus: battery.energySaverStatus)
        defer { HostBoundary.setBatteryInfo(before) }
        battery.state = .unknown

        AppKitEnvironment(core: CoreLink()).reportBattery()

        XCTAssertNotEqual(battery.state, .unknown)
        XCTAssertNotEqual(battery.energySaverStatus, .unknown)
        XCTAssertTrue((0...1).contains(battery.chargeLevel), "\(battery.chargeLevel)")
    }
}

#endif
