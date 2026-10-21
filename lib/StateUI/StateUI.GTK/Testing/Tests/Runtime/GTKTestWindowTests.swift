// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUITesting
@testable import StateUIGTKDriver
import XCTest

/// An application's test window walked through GTK's own widgets: the same test reads alike here and with no
/// toolkit.
final class GTKTestWindowTests: XCTestCase {
    func testATestWindowWalksOnGTK() {
        onUIThread {
            XCTAssertEqual(TestWindowWalk.failures(on: GTKDriver()), [])
        }
    }
}
