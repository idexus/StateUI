// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitSliderViewTests: XCTestCase {
    @MainActor
    func testASliderAppliesItsNativeRangeBeforeItsValue() {
        let view = AppKitSliderView()

        view.apply(
            value: 40,
            writeValue: true,
            minimum: 20,
            maximum: 80,
            minimumTrackColor: .systemBlue,
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
            writeValue: true,
            minimum: 80,
            maximum: 20,
            minimumTrackColor: nil,
            enabled: true)

        XCTAssertEqual(view.minValue, 20)
        XCTAssertEqual(view.maxValue, 80)
        XCTAssertEqual(view.doubleValue, 30)
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
            writeValue: true,
            minimum: 0,
            maximum: 1,
            minimumTrackColor: nil,
            enabled: true)

        view.doubleValue = 0.625
        view.valueChanged(view)

        XCTAssertEqual(reports, [0.625])
    }

    @MainActor
    func testDragBoundariesAreReportedExactlyOnce() {
        let view = AppKitSliderView()
        var events: [String] = []
        view.onDragStarted = { events.append("start") }
        view.onDragCompleted = { events.append("complete") }

        view.beginDrag()
        view.endDrag()

        XCTAssertEqual(events, ["start", "complete"])
    }
}

#endif
