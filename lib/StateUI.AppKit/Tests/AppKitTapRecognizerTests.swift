// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@testable import StateUIAppKit
import XCTest

final class AppKitTapRecognizerTests: XCTestCase {
    @MainActor
    func testATapUsesTheRequestedNativeClickCount() {
        let recognizer = AppKitTapRecognizer {}

        recognizer.apply(numberOfTapsRequired: 2)

        XCTAssertEqual(recognizer.numberOfClicksRequired, 2)
    }

    @MainActor
    func testAnInvalidTapCountStillDescribesOneTap() {
        let recognizer = AppKitTapRecognizer {}

        recognizer.apply(numberOfTapsRequired: 0)

        XCTAssertEqual(recognizer.numberOfClicksRequired, 1)
    }

    @MainActor
    func testARecognizedTapReportsExactlyOnce() {
        var reports = 0
        let recognizer = AppKitTapRecognizer { reports += 1 }

        recognizer.fire()

        XCTAssertEqual(reports, 1)
    }
}

#endif
