// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// What a host reads of the machine it stands on, as the core is told it on every host, and the one step that
/// follows a change of it.
final class EnvironmentFactsTests: XCTestCase {
    /// A locale is eight words; the week's first day counts from Sunday's 0; any other count is no locale.
    func testALocaleIsEightWords() throws {
        let locale = try XCTUnwrap(HostLocaleInfo(words: ["ar", "EG", "ar-EG", "Africa/Cairo", "1", "6", "1", "1"]))
        XCTAssertEqual(locale.language, "ar")
        XCTAssertEqual(locale.timeZone, "Africa/Cairo")
        XCTAssertTrue(locale.uses24HourClock)
        XCTAssertEqual(locale.firstDayOfWeek, .saturday)
        XCTAssertTrue(locale.isMetric)
        XCTAssertEqual(locale.layoutDirection, .rightToLeft)
        XCTAssertNil(HostLocaleInfo(words: ["en", "US"]))
    }

    /// A device is five words on its platform: its model, its maker, its name, its system's version, and whether
    /// it is a virtual machine.
    func testADeviceIsFiveWords() throws {
        let device = try XCTUnwrap(HostDeviceInfo(
            words: ["Surface", "Microsoft", "desk", "10.0", "1"], formFactor: .desktop, platform: "Windows"))
        XCTAssertEqual(device.manufacturer, "Microsoft")
        XCTAssertEqual(device.deviceType, .virtual)
        XCTAssertNil(HostDeviceInfo(words: [], formFactor: .desktop, platform: "Windows"))
    }

    /// The network is its access by number and one bit a connection in use.
    func testTheNetworkIsItsAccessAndABitAConnection() {
        let network = HostConnectivityInfo(access: NetworkAccess.internet.rawValue, connections: 4 | 8)
        XCTAssertEqual(network.networkAccess, .internet)
        XCTAssertEqual(network.connectionProfiles, [.ethernet, .wiFi])
        XCTAssertEqual(HostConnectivityInfo(access: 99, connections: 0).networkAccess, .unknown)
    }

    /// A desktop's power: no battery is mains and full; one charging charges, one off mains discharges, one on
    /// mains is full or waits.
    func testADesktopsPowerIsItsBatterysState() {
        func state(charging: Bool, onMains: Bool, full: Bool) -> BatteryState {
            HostBatteryInfo(present: true, level: 0.5, charging: charging, onMains: onMains, full: full, saving: false)
                .state
        }
        let none = HostBatteryInfo(present: false, level: 0.2, charging: false, onMains: false, full: false, saving: true)
        XCTAssertEqual(none.state, .notPresent)
        XCTAssertEqual(none.powerSource, .ac)
        XCTAssertEqual(none.chargeLevel, 1)
        XCTAssertEqual(none.energySaverStatus, .on)
        XCTAssertEqual(state(charging: true, onMains: true, full: false), .charging)
        XCTAssertEqual(state(charging: false, onMains: false, full: false), .discharging)
        XCTAssertEqual(state(charging: false, onMains: true, full: true), .full)
        XCTAssertEqual(state(charging: false, onMains: true, full: false), .notCharging)
        XCTAssertEqual(
            HostBatteryInfo(present: true, level: 1.4, charging: false, onMains: true, full: true, saving: false)
                .chargeLevel, 1)
    }

    /// A screen at least as wide as it is tall is landscape.
    func testAScreenAsWideAsItIsTallIsLandscape() {
        XCTAssertEqual(HostDisplayInfo(width: 100, height: 100, density: 2, refreshRate: 60).orientation, .landscape)
        XCTAssertEqual(HostDisplayInfo(width: 90, height: 100, density: 2, refreshRate: 60).orientation, .portrait)
    }

    /// A change of the environment tells the core what stands now, turns the tree to the language's direction, and
    /// renders.
    @MainActor
    func testAChangedEnvironmentIsToldFollowedAndRendered() throws {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([HostPatch(id: .manual("label"), type: .label)])
        runtime.tree.apply(root, complete: true)
        let rightToLeft = try XCTUnwrap(HostLocaleInfo(words: ["he", "IL", "he-IL", "Asia/Jerusalem", "1", "0", "1", "1"]))
        let leftToRight = try XCTUnwrap(HostLocaleInfo(words: ["en", "GB", "en-GB", "Europe/London", "1", "1", "1", "0"]))
        defer { runtime.core.setLocaleInfo(leftToRight) }

        var told = false
        runtime.environmentChanged {
            told = true
            runtime.core.setLocaleInfo(rightToLeft)
        }

        XCTAssertTrue(told)
        XCTAssertEqual(runtime.tree.languageDirection, .rightToLeft, "the tree follows the language's direction")
    }
}
