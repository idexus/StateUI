// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid

final class AndroidPixelBoundsTests: XCTestCase {
    static var allTests: [(String, (AndroidPixelBoundsTests) -> () throws -> Void)] {
        [
            ("testPixelCoordinatesKeepSignsAndRefuseNumbersOutsideInt32", testPixelCoordinatesKeepSignsAndRefuseNumbersOutsideInt32),
            ("testMeasuredSizesFitThePlatformsActualSizeMask", testMeasuredSizesFitThePlatformsActualSizeMask),
            ("testFramesRoundOutwardWithinTheirNativeBounds", testFramesRoundOutwardWithinTheirNativeBounds),
            ("testNonfinitePublicPaddingContributesNoDistance", testNonfinitePublicPaddingContributesNoDistance),
            ("testPaddingAndMenuRoomCannotOverflowTogether", testPaddingAndMenuRoomCannotOverflowTogether),
            ("testExtremeCoordinateMovesReachTheAskedNativeFrame", testExtremeCoordinateMovesReachTheAskedNativeFrame),
            ("testASlidersNonfiniteInputUsesItsRangeRule", testASlidersNonfiniteInputUsesItsRangeRule),
        ]
    }

    func testPixelCoordinatesKeepSignsAndRefuseNumbersOutsideInt32() {
        XCTAssertEqual(AndroidPixels.distance(-3.5, density: 2), -7)
        XCTAssertEqual(AndroidPixels.distance(3.5, density: 2), 7)
        XCTAssertEqual(AndroidPixels.distance(Double(Int32.min)), Int32.min)
        XCTAssertEqual(AndroidPixels.distance(Double(Int32.max)), Int32.max)
        for number in [Double(Int32.max) + 1, Double(Int32.min) - 1, 1e100, .infinity, -.infinity, .nan] {
            XCTAssertEqual(AndroidPixels.distance(number), 0)
        }
        XCTAssertEqual(AndroidPixels.distance(Double(Int32.max), density: 2), 0)
    }

    func testMeasuredSizesFitThePlatformsActualSizeMask() {
        onMainActor {
            XCTAssertEqual(AndroidPixels.maximumSize, Java.staticInt(JavaAPI.view, "MEASURED_SIZE_MASK"))
            XCTAssertEqual(AndroidPixels.size(Double(AndroidPixels.maximumSize)), AndroidPixels.maximumSize)
            for number in [Double(AndroidPixels.maximumSize) + 1, -1, 1e100, .infinity, .nan] {
                XCTAssertEqual(AndroidPixels.size(number), 0)
            }
            XCTAssertEqual(AndroidPixels.size(2.25, density: 2), 5)
            XCTAssertEqual(ViewConstants.size(ViewConstants.spec(ViewConstants.exactly, 0x4000_0000)), 0)
            XCTAssertEqual(ViewConstants.size(ViewConstants.spec(ViewConstants.exactly, 123)), 123)
        }
    }

    func testFramesRoundOutwardWithinTheirNativeBounds() {
        let frame = AndroidPixels.frame(Rect(0.2, -1.25, 3.3, 2), density: 2.625)
        XCTAssertEqual([frame.left, frame.top, frame.right, frame.bottom], [0, -4, 10, 2])
        for rectangle in [Rect(0, 0, 1e100, 1), Rect(Double(Int32.max) - 1, 0, 4, 1), Rect(1e100, 0, 4, 1)] {
            let frame = AndroidPixels.frame(rectangle, density: 1)
            XCTAssertEqual(frame.right, frame.left, "an unrepresentable extent is empty")
            XCTAssertEqual(frame.bottom - frame.top, 1)
        }
        let empty = AndroidPixels.frame(Rect(0, 0, .nan, .infinity), density: 2)
        XCTAssertEqual([empty.left, empty.top, empty.right, empty.bottom], [0, 0, 0, 0])
    }

    func testNonfinitePublicPaddingContributesNoDistance() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                Button("Padding").padding(start: 3, top: .nan, end: .infinity, bottom: 4)
            }
            let button = try XCTUnwrap(host.views(AndroidButtonView.self).first)
            let sides = [JavaAPI.getPaddingLeft, JavaAPI.getPaddingTop, JavaAPI.getPaddingRight, JavaAPI.getPaddingBottom]
                .map { Java.callInt(button.reference, $0) }
            XCTAssertEqual(sides, [6, 0, 0, 8])
        }
    }

    func testPaddingAndMenuRoomCannotOverflowTogether() {
        onMainActor {
            let host = AndroidRenderer.running { VStack {} }
            let view = AndroidTextView()
            view.setPadding(Insets(start: 0, top: 0, end: Double(Int32.max) / view.density, bottom: 0))
            view.rightRoom = 1
            XCTAssertEqual(Java.callInt(view.reference, JavaAPI.getPaddingRight), 0)
            withExtendedLifetime(host) {}
        }
    }

    func testExtremeCoordinateMovesReachTheAskedNativeFrame() {
        onMainActor {
            let host = AndroidRenderer.running { VStack {} }
            let view = AndroidView { _ in
                Java.new(JavaAPI.view, JavaAPI.newView, .object(TestContext.context.reference))
            }
            for coordinate in [Int32.min, Int32.max, -4] {
                view.layout(Rect(Double(coordinate) / view.density, 0, 0, 0))
                XCTAssertEqual(Java.callInt(view.reference, JavaAPI.getLeft), coordinate)
                XCTAssertEqual(Java.callInt(view.reference, JavaAPI.getRight), coordinate)
            }
            withExtendedLifetime(host) {}
        }
    }

    func testASlidersNonfiniteInputUsesItsRangeRule() {
        onMainActor {
            let host = AndroidRenderer.running { VStack {} }
            let slider = AndroidSliderView()
            for (input, expected) in [(Double.nan, 0.0), (.infinity, 10), (-.infinity, 0)] {
                slider.apply(value: input, minimum: 0, maximum: 10)
                XCTAssertEqual(slider.value, expected)
            }
            withExtendedLifetime(host) {}
        }
    }
}
