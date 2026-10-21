// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
import XCTest

/// What the application stands on, as UIKit tells it: the theme, the user's locale, the battery.
@MainActor
final class UIKitEnvironmentTests: XCTestCase {
    /// The theme is followed on a scene iOS holds: one it let go of is followed no more, and the scene connecting
    /// next is - iOS makes a scene anew for a session it brings back.
    @MainActor
    func testTheThemeIsFollowedOnAConnectedScene() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        let host = UIKitRenderer.running { Text("Themed") }
        defer { host.finish() }
        XCTAssertTrue(host.environment.followedSceneForTesting === scene)

        host.disconnect(scene)
        XCTAssertNil(host.environment.followedSceneForTesting, "a scene let go of is followed no more")

        host.connect(scene)
        XCTAssertTrue(host.environment.followedSceneForTesting === scene, "the scene connecting is")
    }

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
        host.settle { StandardEnvironment.application.info.colorScheme == .dark }
        XCTAssertEqual(StandardEnvironment.application.info.colorScheme, .dark)

        scene.traitOverrides.userInterfaceStyle = .light
        host.settle { StandardEnvironment.application.info.colorScheme == .light }
        XCTAssertEqual(StandardEnvironment.application.info.colorScheme, .light)
    }

    /// A window the user is not in stands inactive: iPadOS keeps every window on screen active and dims those behind
    /// the one the user works in - and the window dimmed is activated again as the user comes back to it.
    @MainActor
    func testAWindowDimmedBehindAnotherStandsInactive() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        let host = UIKitRenderer.running { Text("Behind") }
        defer {
            scene.traitOverrides.remove(UITraitActiveAppearance.self)
            host.finish()
        }
        host.settle { StandardEnvironment.application.phase == .active }

        scene.traitOverrides.activeAppearance = .inactive
        host.settle { StandardEnvironment.application.phase == .inactive }
        XCTAssertEqual(StandardEnvironment.application.phase, .inactive, "dimmed behind another window")

        scene.traitOverrides.activeAppearance = .active
        host.settle { StandardEnvironment.application.phase == .active }
        XCTAssertEqual(StandardEnvironment.application.phase, .active, "the user came back to it")
    }

    /// The display is the screen as the scene stands on it now: turned a quarter, it is landscape, its width and
    /// height swapped, and says the turn.
    @MainActor
    func testTheDisplayIsTheScreenAsItIsTurned() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        let display = StandardEnvironment.device.display
        let environment = UIKitEnvironment(core: CoreLink())
        defer { Self.turn(scene, to: .portrait) }

        Self.turn(scene, to: .portrait)
        guard scene.effectiveGeometry.interfaceOrientation == .portrait else {
            throw XCTSkip("iOS turns this scene with the device alone, as it does an iPad's")
        }
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

    /// The display's turn is told before the page is laid out turned: what hears the turned room hears the turned
    /// display with it, so an answer worked out from the two holds - and is not left standing on the display's last
    /// turn, which a page turned back never measures again.
    @MainActor
    func testTheDisplayTurnsBeforeThePageIsLaidOutTurned() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        Self.turn(scene, to: .portrait)
        guard scene.effectiveGeometry.interfaceOrientation == .portrait else {
            throw XCTSkip("iOS turns this scene with the device alone, as it does an iPad's")
        }
        let heard = Received<[Bool]>()
        let host = UIKitRenderer.running {
            VStack { Rectangle().fill(.steelBlue) }
                .onFrameChanged { room in
                    heard.values.append([
                        room.width > room.height, StandardEnvironment.device.display.orientation == .landscape,
                    ])
                }
        }
        defer {
            host.finish()
            Self.turn(scene, to: .portrait)
        }
        host.settle { !heard.values.isEmpty }

        Self.turn(scene, to: .landscapeRight)
        guard scene.effectiveGeometry.interfaceOrientation == .landscapeRight else {
            throw XCTSkip("iOS turns this scene with the device alone, as it does an iPad's")
        }
        host.settle { heard.values.last?.first == true }
        XCTAssertEqual(heard.values.last, [true, true], "the wide room is heard with the display turned")

        Self.turn(scene, to: .portrait)
        host.settle { heard.values.last?.first == false }
        XCTAssertEqual(heard.values.last, [false, false], "and the tall one with the display turned back")
    }

    /// Asks iOS to turn `scene` to `orientation`, and waits until it has.
    @MainActor
    private static func turn(_ scene: UIWindowScene, to orientation: UIInterfaceOrientation) {
        let mask: UIInterfaceOrientationMask = orientation == .portrait ? .portrait : .landscapeRight
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        for _ in 0..<200 {
            guard scene.effectiveGeometry.interfaceOrientation != orientation else { break }
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
        let battery = StandardEnvironment.device.battery
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

    /// The accessibility settings reported are the device's own: less motion, darker colours and VoiceOver as UIKit
    /// says them, and the scale of words the size the user chose draws - 1 at the size iOS starts at.
    @MainActor
    func testTheAccessibilitySettingsReportedAreTheDevices() {
        let settings = StandardEnvironment.device.accessibility
        defer {
            HostBoundary.setAccessibilityInfo(HostAccessibilityInfo(
                reducesMotion: false, prefersHigherContrast: false, isScreenReaderOn: false, textScale: 1))
        }
        HostBoundary.setAccessibilityInfo(HostAccessibilityInfo(
            reducesMotion: !UIAccessibility.isReduceMotionEnabled,
            prefersHigherContrast: !UIAccessibility.isDarkerSystemColorsEnabled,
            isScreenReaderOn: !UIAccessibility.isVoiceOverRunning, textScale: 0))

        UIKitEnvironment(core: CoreLink()).reportAccessibility()

        XCTAssertEqual(settings.reducesMotion, UIAccessibility.isReduceMotionEnabled)
        XCTAssertEqual(settings.prefersHigherContrast, UIAccessibility.isDarkerSystemColorsEnabled)
        XCTAssertEqual(settings.isScreenReaderOn, UIAccessibility.isVoiceOverRunning)
        if UIApplication.shared.preferredContentSizeCategory == .large {
            XCTAssertEqual(settings.textScale, 1, accuracy: 0.001)
        } else {
            XCTAssertNotEqual(settings.textScale, 1)
        }
    }
}
