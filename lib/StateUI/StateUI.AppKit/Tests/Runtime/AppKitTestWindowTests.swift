// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUITesting
import XCTest

/// An application's test window walked through AppKit's own controls: the same test reads alike here and with no
/// toolkit.
@MainActor
final class AppKitTestWindowTests: XCTestCase {
    func testATestWindowWalksOnAppKit() {
        let driver = AppKitDriver()
        defer { driver.renderer?.closeForTesting() }
        XCTAssertEqual(TestWindowWalk.failures(on: driver), [])
    }
}
#endif
