// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The layout arithmetic every Swift host places its children with.
final class LayoutArithmeticTests: XCTestCase {
    /// A contradiction between a least and a most size is settled by the least; the room caps both.
    func testTheLeastSizeWinsAndTheRoomCaps() {
        XCTAssertEqual(Extent.bounded(10, minimum: 40, maximum: 20), 40)
        XCTAssertEqual(Extent.bounded(90, minimum: nil, maximum: 50), 50)
        XCTAssertEqual(Extent.bounded(90, minimum: nil, maximum: nil, available: 30), 30)
        XCTAssertEqual(Extent.bounded(.nan, minimum: 5, maximum: nil), 5)
    }

    /// A vertical stack sets shown children one under another; a hidden one takes no room and no spacing.
    @MainActor
    func testAVerticalStackPlacesItsShownChildrenInOrder() {
        var centred = Child(width: 20, height: 10)
        centred.values.horizontal = 1
        let items = [Child(width: 20, height: 10), Child(width: 20, height: 10, shown: false), centred]

        let size = StackArithmetic.size(of: items, axis: .vertical, spacing: 5, padding: Insets(2), width: nil)
        let places = StackArithmetic.places(
            of: items, axis: .vertical, spacing: 5, padding: Insets(2), in: Rect(0, 0, 100, 50))

        XCTAssertEqual(size, LayoutSize(width: 24, height: 29))
        XCTAssertEqual(places[0], Rect(2, 2, 96, 10), "a filling child takes the slot's width")
        XCTAssertNil(places[1])
        XCTAssertEqual(places[2], Rect(40, 17, 20, 10), "a centred child stands in the middle")
    }

    /// Fixed tracks take their length, automatic tracks their child, proportional tracks share the rest.
    @MainActor
    func testGridTracksShareTheRoomByKind() {
        var fixed = Child(width: 10, height: 10)
        fixed.values.column = 0
        var automatic = Child(width: 30, height: 10)
        automatic.values.column = 1
        var shared = Child(width: 5, height: 10)
        shared.values.column = 2
        let columns: [GridLength] = [.fixed(20), .auto, .proportional(1)]

        let places = GridArithmetic.places(
            of: [fixed, automatic, shared], rows: [], columns: columns,
            rowSpacing: 0, columnSpacing: 0, padding: Insets(0), in: Rect(0, 0, 100, 10))

        XCTAssertEqual(places.map { $0?.x }, [0, 20, 50])
        XCTAssertEqual(places.map { $0?.width }, [20, 30, 50])
    }

    /// Words in a proportional column wrap to it: their row is as tall as they are at the column's width, where
    /// the grid places them and where it is measured for a width narrower than its words.
    @MainActor
    func testARowIsAsTallAsItsWordsAtTheirColumnsWidth() {
        let icon = Child(width: 20, height: 20)
        var words = Child(width: 300, height: 10)
        words.wraps = true
        words.values.column = 1
        let columns: [GridLength] = [.auto, .fill]

        let places = GridArithmetic.places(
            of: [icon, words], rows: [.auto], columns: columns,
            rowSpacing: 0, columnSpacing: 0, padding: Insets(0), in: Rect(0, 0, 120, 200))
        let size = GridArithmetic.size(
            of: [icon, words], rows: [.auto], columns: columns,
            rowSpacing: 0, columnSpacing: 0, padding: Insets(0), width: 120)

        XCTAssertEqual(places[1], Rect(20, 0, 100, 30), "three lines of words at the column's 100")
        XCTAssertEqual(size.height, 30)
        XCTAssertEqual(size.width, 320, "its natural width is still its words on one line")
    }

    /// A proportional position of one puts a child against the far edge of the room left beside it.
    @MainActor
    func testAProportionalPositionOfOneMeetsTheFarEdge() {
        var child = Child(width: 20, height: 10)
        child.values.absoluteBounds = [1, 0, -1, -1]
        child.values.absoluteProportions = 1

        let places = AbsoluteArithmetic.places(of: [child], in: LayoutSize(width: 100, height: 50))

        XCTAssertEqual(places.first, Rect(80, 0, 20, 10))
    }

    /// A child that fills both ways takes the room within the padding, whatever it would measure.
    @MainActor
    func testASingleFillingChildTakesTheRoom() {
        let place = SingleChildArithmetic.place(of: Child(width: 5, height: 5), in: Rect(0, 0, 100, 40), padding: Insets(10))

        XCTAssertEqual(place, Rect(10, 10, 80, 20))
    }

    /// A kept size answers for its width until it is forgotten; a pass needs at most a few.
    @MainActor
    func testAMeasurementIsKeptPerOfferedWidth() {
        let cache = MeasurementCache()
        var measured = 0
        func size(_ width: Double?) -> LayoutSize {
            cache.size(offering: width) { measured += 1; return LayoutSize(width: width ?? 1, height: 1) }
        }

        _ = size(10); _ = size(10); _ = size(nil)
        XCTAssertEqual(measured, 2)
        cache.invalidate()
        _ = size(10)
        XCTAssertEqual(measured, 3)
    }
}

/// A child of a stated natural size; one that wraps is as wide as that on one line, and a line taller for each
/// time it has to break to fit a narrower width.
private struct Child: LayoutChild {
    var values = LayoutValues()
    let natural: LayoutSize
    let isShown: Bool
    var wraps = false

    init(width: Double, height: Double, shown: Bool = true) {
        natural = LayoutSize(width: width, height: height)
        isShown = shown
    }

    func size(offered width: Double?) -> LayoutSize {
        if wraps, let width, width > 0, width < natural.width {
            return LayoutSize(width: width, height: natural.height * (natural.width / width).rounded(.up))
        }
        return LayoutSize(
            width: values.boundedWidth(values.width ?? natural.width),
            height: values.boundedHeight(values.height ?? natural.height))
    }
}
