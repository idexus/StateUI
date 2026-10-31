// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUITesting
@testable import StateUIWinUIDriver
import XCTest

/// An application's test window walked through WinUI's own controls: the same test reads alike here and with no
/// toolkit.
final class WinUITestWindowTests: XCTestCase {
    func testATestWindowWalksOnWinUI() {
        onUIThread {
            XCTAssertEqual(TestWindowWalk.failures(on: WinUIDriver()), [])
        }
    }
}
