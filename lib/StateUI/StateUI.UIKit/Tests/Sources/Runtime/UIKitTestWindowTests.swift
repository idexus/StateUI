// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUITesting
import XCTest

/// An application's test window walked through UIKit's own controls: the same test reads alike here and with no
/// toolkit.
@MainActor
final class UIKitTestWindowTests: XCTestCase {
    func testATestWindowWalksOnUIKit() {
        let driver = UIKitDriver()
        defer { driver.finish() }
        XCTAssertEqual(TestWindowWalk.failures(on: driver), [])
    }
}
