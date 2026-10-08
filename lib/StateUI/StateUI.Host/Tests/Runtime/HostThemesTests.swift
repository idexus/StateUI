// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The theme in force is the application's where it holds one, else the system's.
@MainActor
final class HostThemesTests: XCTestCase {
    func testTheApplicationsThemeWinsUntilItFollowsTheSystem() {
        XCTAssertEqual(HostThemes.inForce(held: .dark, system: .light), .dark)
        XCTAssertEqual(HostThemes.inForce(held: .light, system: .dark), .light)
        XCTAssertEqual(HostThemes.inForce(held: .system, system: .dark), .dark)
        XCTAssertEqual(HostThemes.inForce(held: .system, system: .light), .light)
    }
}
