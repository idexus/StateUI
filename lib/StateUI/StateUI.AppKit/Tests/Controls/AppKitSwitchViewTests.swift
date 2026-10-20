// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

@MainActor
final class AppKitSwitchViewTests: XCTestCase {
    @MainActor
    func testStateWritesDoNotBecomeUserReports() {
        let toggle = AppKitSwitchView()
        var reports: [Bool] = []
        toggle.onToggled = { reports.append($0) }

        toggle.apply(toggled: true, enabled: true, text: "", textColor: nil)
        toggle.apply(toggled: false, enabled: false, text: "", textColor: nil)

        XCTAssertTrue(reports.isEmpty)
        XCTAssertEqual(toggle.state, .off)
        XCTAssertFalse(toggle.control.isEnabled)
    }

    @MainActor
    func testAUserFlipReportsTheSettledBooleanOnce() {
        let toggle = AppKitSwitchView()
        var reports: [Bool] = []
        toggle.onToggled = { reports.append($0) }
        toggle.apply(toggled: false, enabled: true, text: "", textColor: nil)

        toggle.toggleForTesting()

        XCTAssertEqual(reports, [true])
        XCTAssertEqual(toggle.state, .on)
    }

    @MainActor
    func testCheckBoxSeparatesStateWritesFromUserWrites() {
        let checkBox = AppKitCheckBoxView()
        var reports: [Bool] = []
        checkBox.onToggled = { reports.append($0) }

        checkBox.apply(checked: true, enabled: false, tint: .systemPurple, text: "", textColor: nil)
        XCTAssertTrue(reports.isEmpty)
        XCTAssertEqual(checkBox.state, .on)
        XCTAssertFalse(checkBox.isEnabled)
        XCTAssertEqual(checkBox.contentTintColor, .systemPurple)

        checkBox.apply(checked: false, enabled: true, tint: nil, text: "", textColor: nil)
        checkBox.toggleForTesting()
        XCTAssertEqual(reports, [true])
    }
}

#endif
