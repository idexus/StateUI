// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitSwitchViewTests: XCTestCase {
    @MainActor
    func testStateWritesDoNotBecomeUserReports() {
        let toggle = AppKitSwitchView()
        var reports: [Bool] = []
        toggle.onToggled = { reports.append($0) }

        toggle.apply(toggled: true, enabled: true)
        toggle.apply(toggled: false, enabled: false)

        XCTAssertTrue(reports.isEmpty)
        XCTAssertEqual(toggle.state, .off)
        XCTAssertFalse(toggle.isEnabled)
    }

    @MainActor
    func testAUserFlipReportsTheSettledBooleanOnce() {
        let toggle = AppKitSwitchView()
        var reports: [Bool] = []
        toggle.onToggled = { reports.append($0) }
        toggle.apply(toggled: false, enabled: true)

        toggle.toggleForTesting()

        XCTAssertEqual(reports, [true])
        XCTAssertEqual(toggle.state, .on)
    }

    @MainActor
    func testCheckBoxSeparatesStateWritesFromUserWrites() {
        let checkBox = AppKitCheckBoxView()
        var reports: [Bool] = []
        checkBox.onToggled = { reports.append($0) }

        checkBox.apply(checked: true, enabled: false, tint: .systemPurple)
        XCTAssertTrue(reports.isEmpty)
        XCTAssertEqual(checkBox.state, .on)
        XCTAssertFalse(checkBox.isEnabled)
        XCTAssertEqual(checkBox.contentTintColor, .systemPurple)

        checkBox.apply(checked: false, enabled: true, tint: nil)
        checkBox.toggleForTesting()
        XCTAssertEqual(reports, [true])
    }
}

#endif
