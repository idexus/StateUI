// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUITesting
import XCTest

/// An application's test window walked through Android's own views: the same test reads alike here and with no
/// toolkit.
final class AndroidTestWindowTests: XCTestCase {
    static var allTests: [(String, (AndroidTestWindowTests) -> () throws -> Void)] {
        [("testATestWindowWalksOnAndroid", testATestWindowWalksOnAndroid)]
    }

    func testATestWindowWalksOnAndroid() throws {
        onMainActor {
            let driver = AndroidDriver()
            defer { driver.finish() }
            XCTAssertEqual(TestWindowWalk.failures(on: driver), [])
        }
    }
}
