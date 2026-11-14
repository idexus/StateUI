// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class AndroidSuiteTests: XCTestCase {
    /// A test its file's `allTests` leaves out, and a case the runner does not name, would never run: both are found.
    func testWhatNoListNamesIsFound() {
        let source = """
            final class AndroidSliderTests: XCTestCase {
                static let allTests = [("testValue", testValue)]
                func testValue() {}
                func testForgotten() {}
            }
            final class AndroidLostTests: XCTestCase {}
            """
        let runner = "testCase(AndroidSliderTests.allTests),"
        XCTAssertEqual(AndroidSuite.unlisted(in: source, runner: runner), ["testForgotten", "AndroidLostTests"])
        XCTAssertEqual(AndroidSuite.unlisted(in: "func testOne() {} (\"testOne\", testOne)", runner: ""), [])
    }

    /// Two verdict files compare by their verdicts, whatever revision each stood at.
    func testVerdictsCompareWithoutTheirRevision() {
        XCTAssertEqual(Verdicts.alone("# revision 2.1\nButton.title ✅\n"), Verdicts.alone("# revision 3.1\nButton.title ✅\n"))
        XCTAssertNotEqual(Verdicts.alone("Button.title ✅"), Verdicts.alone("Button.title ❌"))
    }
}
