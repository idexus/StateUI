// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// What the application stands on, as UIKit tells it: the theme, the user's locale, the battery.
final class UIKitEnvironmentTests: XCTestCase {
    /// The theme is the one the user's scene stands in: turning dark tells it, and turning light again.
    @MainActor
    func testTheThemeIsTheScenes() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        let host = UIKitRenderer.running { Text("Themed") }
        defer {
            scene.traitOverrides.remove(UITraitUserInterfaceStyle.self)
            host.finish()
        }

        scene.traitOverrides.userInterfaceStyle = .dark
        host.settle { StandardEnvironment.app.requestedTheme == .dark }
        XCTAssertEqual(StandardEnvironment.app.requestedTheme, .dark)

        scene.traitOverrides.userInterfaceStyle = .light
        host.settle { StandardEnvironment.app.requestedTheme == .light }
        XCTAssertEqual(StandardEnvironment.app.requestedTheme, .light)
    }

    /// The display is the screen as the scene stands on it now: turned a quarter, it is landscape, its width and
    /// height swapped, and says the turn.
    @MainActor
    func testTheDisplayIsTheScreenAsItIsTurned() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        let display = StandardEnvironment.display
        let environment = UIKitEnvironment(core: CoreLink())
        defer { Self.turn(scene, to: .portrait) }

        Self.turn(scene, to: .portrait)
        environment.reportDisplay(of: scene)
        XCTAssertEqual(display.orientation, .portrait)
        XCTAssertEqual(display.rotation, .rotation0)
        let (width, height) = (display.width, display.height)

        Self.turn(scene, to: .landscapeRight)
        guard scene.effectiveGeometry.interfaceOrientation == .landscapeRight else {
            throw XCTSkip("iOS turns this scene with the device alone, as it does an iPad's")
        }
        environment.reportDisplay(of: scene)
        XCTAssertEqual(display.orientation, .landscape)
        XCTAssertEqual(display.rotation, .rotation90)
        XCTAssertEqual([display.width, display.height], [height, width])
    }

    /// Asks iOS to turn `scene` to `orientation`, and waits until it has.
    @MainActor
    private static func turn(_ scene: UIWindowScene, to orientation: UIInterfaceOrientation) {
        let mask: UIInterfaceOrientationMask = orientation == .portrait ? .portrait : .landscapeRight
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        for _ in 0..<200 where scene.effectiveGeometry.interfaceOrientation != orientation {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    /// The locale reported is the user's: their language, region, zone and the direction their language is written.
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

        UIKitEnvironment(core: CoreLink()).reportLocale()

        XCTAssertEqual(locale.name, Locale.current.identifier(.bcp47))
        XCTAssertEqual(locale.language, Locale.current.language.languageCode?.identifier ?? "")
        XCTAssertEqual(locale.timeZone, TimeZone.current.identifier)
        XCTAssertEqual(
            locale.layoutDirection,
            Locale.current.language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight)
    }

    /// The battery report says something settled: a level from 0 to 1 and a state, `notPresent` where UIKit knows
    /// none, as on the simulator.
    @MainActor
    func testTheBatteryReportedIsSettled() {
        let battery = StandardEnvironment.battery
        let before = HostBatteryInfo(
            chargeLevel: battery.chargeLevel, state: battery.state, powerSource: battery.powerSource,
            energySaverStatus: battery.energySaverStatus)
        defer { HostBoundary.setBatteryInfo(before) }
        battery.state = .unknown

        UIKitEnvironment(core: CoreLink()).reportBattery()

        XCTAssertNotEqual(battery.state, .unknown)
        XCTAssertNotEqual(battery.energySaverStatus, .unknown)
        XCTAssertTrue((0...1).contains(battery.chargeLevel))
    }
}
