// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

@MainActor
final class AppKitSliderViewTests: XCTestCase {
    @MainActor
    func testASliderAppliesItsNativeRangeBeforeItsValue() {
        let view = AppKitSliderView()

        view.apply(
            value: 40,
            minimum: 20,
            maximum: 80,
            tint: .systemBlue,
            enabled: false)

        XCTAssertEqual(view.minValue, 20)
        XCTAssertEqual(view.maxValue, 80)
        XCTAssertEqual(view.doubleValue, 40)
        XCTAssertTrue(view.trackFillColor?.isEqual(NSColor.systemBlue) == true)
        XCTAssertFalse(view.isEnabled)
        XCTAssertTrue(view.isContinuous)
    }

    @MainActor
    func testAnInvertedRangeIsNormalizedDeterministically() {
        let view = AppKitSliderView()

        view.apply(
            value: 30,
            minimum: 80,
            maximum: 20,
            tint: nil,
            enabled: true)

        XCTAssertEqual(view.minValue, 20)
        XCTAssertEqual(view.maxValue, 80)
        XCTAssertEqual(view.doubleValue, 30)
    }

    /// An arrow key moves the thumb a hundredth of the range and a page key a tenth, as on every host
    /// (`ValueArithmetic.sliderSteps`), and each move is the user's.
    @MainActor
    func testTheKeysMoveTheThumbAHundredthAndATenthOfTheRange() {
        let view = AppKitSliderView()
        var reports: [Double] = []
        view.onValueChanged = { reports.append($0) }
        view.apply(value: 50, minimum: 0, maximum: 200, tint: nil, enabled: true)

        view.moveRight(nil)
        XCTAssertEqual(view.doubleValue, 52, accuracy: 1e-9)
        view.moveDown(nil)
        XCTAssertEqual(view.doubleValue, 50, accuracy: 1e-9)
        view.pageUp(nil)
        XCTAssertEqual(view.doubleValue, 70, accuracy: 1e-9)
        view.moveLeft(nil)
        view.pageDown(nil)
        XCTAssertEqual(view.doubleValue, 48, accuracy: 1e-9)
        view.apply(value: 199, minimum: 0, maximum: 200, tint: nil, enabled: true)
        view.pageUp(nil)
        XCTAssertEqual(view.doubleValue, 200, accuracy: 1e-9, "a key stops at the range's end")
        XCTAssertEqual(reports, [52, 50, 70, 68, 48, 200])
    }

    @MainActor
    func testAStateWriteDoesNotBecomeAUserReport() {
        let view = AppKitSliderView()
        var reports: [Double] = []
        view.onValueChanged = { reports.append($0) }

        view.setValue(0.75)

        XCTAssertEqual(view.doubleValue, 0.75)
        XCTAssertTrue(reports.isEmpty)
    }

    @MainActor
    func testAUserMoveReportsTheNativeValue() {
        let view = AppKitSliderView()
        var reports: [Double] = []
        view.onValueChanged = { reports.append($0) }
        view.apply(
            value: 0,
            minimum: 0,
            maximum: 1,
            tint: nil,
            enabled: true)

        view.doubleValue = 0.625
        view.valueChanged(view)

        XCTAssertEqual(reports, [0.625])
    }

    @MainActor
    func testDragBoundariesAreReportedExactlyOnce() {
        let view = AppKitSliderView()
        var events: [String] = []
        view.onPressed = { events.append("start") }
        view.onReleased = { events.append("complete") }

        view.beginDrag()
        view.endDrag()

        XCTAssertEqual(events, ["start", "complete"])
    }

    /// Grabbing the thumb and letting it go reach the page's drag handlers,
    /// each as it happens.
    @MainActor
    func testAUsersDragReachesTheSlidersDragHandlers() throws {
        let moments = Received<String>()
        let renderer = AppKitRenderer.running {
            Slider(0.5)
                .onPressed { moments.values.append("started") }
                .onReleased { moments.values.append("completed") }
        }
        defer { renderer.closeForTesting() }
        let slider = try XCTUnwrap(renderer.nativeViews(AppKitSliderView.self).first)

        slider.beginDrag()
        XCTAssertEqual(moments.values, ["started"])
        slider.endDrag()

        XCTAssertEqual(moments.values, ["started", "completed"])
    }
}

#endif
