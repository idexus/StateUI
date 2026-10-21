// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import Foundation
import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit

/// The locale and the battery the host reports are the Mac's own, each told to the core in one report.
@MainActor
final class AppKitEnvironmentTests: XCTestCase {
    /// An environment let go of watches nothing more: the power source it hangs on the main run loop, which holds
    /// it by an unretained pointer, comes off with it, and so does every observer.
    @MainActor
    func testAnEnvironmentLetGoWatchesNothing() throws {
        var environment: AppKitEnvironment? = AppKitEnvironment(core: CoreLink())
        environment?.watch()
        let source = try XCTUnwrap(environment?.powerSourceForTesting)
        XCTAssertTrue(CFRunLoopContainsSource(CFRunLoopGetMain(), source, .defaultMode))
        weak let gone = environment

        environment = nil

        XCTAssertNil(gone)
        XCTAssertFalse(CFRunLoopContainsSource(CFRunLoopGetMain(), source, .defaultMode), "the power source came off")
    }

    /// The accent reported is the one the user chose for the system, as the application's appearance draws it.
    func testTheAccentReportedIsTheUsers() {
        let info = StandardEnvironment.application.info
        let before = info.accentColor
        defer { HostBoundary.setAccentColor(before) }
        HostBoundary.setAccentColor(Color(hex: 0x000000, opacity: 0))

        AppKitEnvironment(core: CoreLink()).reportAccent()

        var accent = NSColor.systemBlue
        NSApplication.shared.effectiveAppearance.performAsCurrentDrawingAppearance {
            accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        }
        func channel(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
        XCTAssertEqual(info.accentColor, Color(
            red: channel(accent.redComponent), green: channel(accent.greenComponent),
            blue: channel(accent.blueComponent), alpha: channel(accent.alphaComponent)))
    }

    /// The accessibility settings reported are the Mac's own: less motion, more contrast and VoiceOver as the
    /// workspace says them, and the scale of words 1, which a Mac keeps none of.
    func testTheAccessibilitySettingsReportedAreTheMacs() {
        let settings = StandardEnvironment.device.accessibility
        defer {
            HostBoundary.setAccessibilityInfo(HostAccessibilityInfo(
                reducesMotion: false, prefersHigherContrast: false, isScreenReaderOn: false, textScale: 1))
        }
        let workspace = NSWorkspace.shared
        HostBoundary.setAccessibilityInfo(HostAccessibilityInfo(
            reducesMotion: !workspace.accessibilityDisplayShouldReduceMotion,
            prefersHigherContrast: !workspace.accessibilityDisplayShouldIncreaseContrast,
            isScreenReaderOn: !workspace.isVoiceOverEnabled, textScale: 2))

        AppKitEnvironment(core: CoreLink()).reportAccessibility()

        XCTAssertEqual(settings.reducesMotion, workspace.accessibilityDisplayShouldReduceMotion)
        XCTAssertEqual(settings.prefersHigherContrast, workspace.accessibilityDisplayShouldIncreaseContrast)
        XCTAssertEqual(settings.isScreenReaderOn, workspace.isVoiceOverEnabled)
        XCTAssertEqual(settings.textScale, 1)
    }

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
        let battery = StandardEnvironment.device.battery
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
