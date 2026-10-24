// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

@MainActor
final class AppKitProgressViewTests: XCTestCase {
    /// The indicator shows exactly while it runs and is visible, whatever
    /// later patch reaches it: running is the spinner's, visibility the
    /// view's, and neither writes the other.
    @MainActor
    func testASpinnerIsShownOnlyWhileVisibleAndRunning() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var stopped = HostPatch(id: .manual("activity"), type: .spinner)
        stopped.properties[.isAnimating] = .bool(false)
        renderer.applyForTesting(tree(stopped))
        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("activity")) as? AppKitSpinnerView)
        XCTAssertFalse(shows(native))

        var margin = HostPatch(id: .manual("activity"), type: .spinner)
        margin.properties[.margin] = .numbers([4, 4, 4, 4])
        renderer.applyForTesting(changedTree(margin))
        XCTAssertFalse(shows(native))

        var runningButInvisible = HostPatch(id: .manual("activity"), type: .spinner)
        runningButInvisible.properties[.isAnimating] = .bool(true)
        runningButInvisible.properties[.isVisible] = .bool(false)
        renderer.applyForTesting(changedTree(runningButInvisible))
        XCTAssertFalse(shows(native))

        var shown = HostPatch(id: .manual("activity"), type: .spinner)
        shown.properties[.isVisible] = .bool(true)
        renderer.applyForTesting(changedTree(shown))
        XCTAssertTrue(shows(native))
    }

    /// What the user sees: a view that is not hidden and draws a spinner.
    @MainActor
    private func shows(_ indicator: AppKitSpinnerView) -> Bool {
        !indicator.isHidden && (indicator.isSpinning || indicator.isDisplayedWhenStopped)
    }

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
    func testSpinnerStartsAndStopsWithoutChangingItsKind() {
        let activity = AppKitSpinnerView()

        activity.apply(running: true)
        XCTAssertTrue(activity.isSpinning)

        activity.apply(running: false)
        XCTAssertFalse(activity.isSpinning)
        XCTAssertFalse(activity.isDisplayedWhenStopped)
        XCTAssertEqual(activity.style, .spinning)
        XCTAssertTrue(activity.isIndeterminate)
    }
}

#endif
