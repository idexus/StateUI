// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIConformance
import XCTest

/// What the Web driver does past the browser it says so: an act done on any element - a window's phase told, a
/// file dialog answered - is the host's own, wherever it is done.
@MainActor
final class WebDriverTests: XCTestCase {
    func testAnActTheDriverDoesItselfIsTheHostsOwnOnAnyElement() {
        let driver = WebDriver()
        for ability in [
            "switchAway on Window", "minimize on Window", "close on Window", "answerFiles on Window",
        ] {
            XCTAssertNotNil(driver.byHost(ability), ability)
        }
        XCTAssertNil(driver.byHost("tap on Button"), "the browser's own input is no host's")
    }
}
