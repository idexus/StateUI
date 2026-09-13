// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitProgressViewTests: XCTestCase {
    @MainActor
    func testProgressIsAClampedFraction() {
        let progress = AppKitProgressView()

        progress.apply(progress: -0.2)
        XCTAssertEqual(progress.doubleValue, 0)

        progress.apply(progress: 0.625)
        XCTAssertEqual(progress.doubleValue, 0.625)

        progress.apply(progress: 1.4)
        XCTAssertEqual(progress.doubleValue, 1)
    }

    @MainActor
    func testProgressUsesTheNativeDeterminateBar() {
        let progress = AppKitProgressView()

        XCTAssertEqual(progress.style, .bar)
        XCTAssertFalse(progress.isIndeterminate)
        XCTAssertEqual(progress.minValue, 0)
        XCTAssertEqual(progress.maxValue, 1)
    }

    @MainActor
    func testActivityIndicatorStartsAndStopsWithoutChangingItsKind() {
        let activity = AppKitActivityIndicatorView()

        activity.apply(running: true)
        XCTAssertTrue(activity.isRunningForTesting)
        XCTAssertFalse(activity.isHidden)

        activity.apply(running: false)
        XCTAssertFalse(activity.isRunningForTesting)
        XCTAssertTrue(activity.isHidden)
        XCTAssertEqual(activity.style, .spinning)
        XCTAssertTrue(activity.isIndeterminate)
    }
}

#endif
