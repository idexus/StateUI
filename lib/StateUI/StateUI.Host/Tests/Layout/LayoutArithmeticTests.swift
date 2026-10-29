// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// The layout arithmetic every Swift host places its children with.
@MainActor
final class LayoutArithmeticTests: XCTestCase {
    /// An inset's start is the left left to right and the right right to left, its end the other way; top and bottom
    /// stand - what a toolkit's own control, padded by left and right, is given.
    func testAnInsetsStartIsTheSideItsDirectionStartsFrom() {
        let insets = Insets(start: 16, top: 4, end: 2, bottom: 8)
        XCTAssertEqual(insets.sides(in: .leftToRight), InsetSides(left: 16, top: 4, right: 2, bottom: 8))
        XCTAssertEqual(insets.sides(in: .rightToLeft), InsetSides(left: 2, top: 4, right: 16, bottom: 8))
    }

    /// A row of an arrangement's own stands across the top or the bottom of its room, the page taking the rest -
    /// never less than none where the row is taller than the room.
    func testARowBesideAPageLeavesItTheRest() {
        let room = Rect(x: 0, y: 10, width: 300, height: 200)
        let top = RowEdge.top.split(room, row: 40)
        XCTAssertEqual(top.row, Rect(x: 0, y: 10, width: 300, height: 40))
        XCTAssertEqual(top.page, Rect(x: 0, y: 50, width: 300, height: 160))
        let bottom = RowEdge.bottom.split(room, row: 40)
        XCTAssertEqual(bottom.row, Rect(x: 0, y: 170, width: 300, height: 40))
        XCTAssertEqual(bottom.page, Rect(x: 0, y: 10, width: 300, height: 160))
        XCTAssertEqual(RowEdge.top.split(room, row: 500).page.height, 0)
        XCTAssertEqual(RowEdge.size(page: LayoutSize(width: 100, height: 60), row: 40), LayoutSize(width: 100, height: 100))
    }

    /// A contradiction between a least and a most size is settled by the least; the room caps both.
    func testTheLeastSizeWinsAndTheRoomCaps() {
        XCTAssertEqual(Extent.bounded(10, minimum: 40, maximum: 20), 40)
        XCTAssertEqual(Extent.bounded(90, minimum: nil, maximum: 50), 50)
        XCTAssertEqual(Extent.bounded(90, minimum: nil, maximum: nil, available: 30), 30)
        XCTAssertEqual(Extent.bounded(.nan, minimum: 5, maximum: nil), 5)
    }

    /// A growing child - a space - takes the room its siblings leave along the stack, shared alike among several,
    /// and none where nothing is left; it measures as no room of its own.
    func testAGrowingChildTakesTheRoomItsSiblingsLeave() {
        var space = Child(width: 0, height: 0)
        space.values.grows = true
        let row = [Child(width: 20, height: 10), space, Child(width: 30, height: 10)]

        let size = StackArithmetic.size(of: row, axis: .horizontal, spacing: 5, padding: Insets(0), width: nil)
        let places = StackArithmetic.places(
            of: row, axis: .horizontal, spacing: 5, padding: Insets(0), in: Rect(0, 0, 200, 10),
            direction: .leftToRight)
        XCTAssertEqual(size, LayoutSize(width: 60, height: 10))
        XCTAssertEqual(places[1], Rect(25, 0, 140, 10), "the 200 less the boxes' 50 and the two spacings' 10")
        XCTAssertEqual(places[2], Rect(170, 0, 30, 10), "the last box stands at the far end")

        let column = [space, Child(width: 10, height: 20), space]
        let shared = StackArithmetic.places(
            of: column, axis: .vertical, spacing: 0, padding: Insets(0), in: Rect(0, 0, 10, 100),
            direction: .leftToRight)
        XCTAssertEqual(shared[1], Rect(0, 40, 10, 20), "two spaces share the room alike")

        let tight = StackArithmetic.places(
            of: row, axis: .horizontal, spacing: 5, padding: Insets(0), in: Rect(0, 0, 40, 10),
            direction: .leftToRight)
        XCTAssertEqual(tight[1]?.width, 0, "no room left, none taken")

        var stated = space
        stated.values.width = 12
        let fixed = StackArithmetic.places(
            of: [Child(width: 20, height: 10), stated], axis: .horizontal, spacing: 0, padding: Insets(0),
            in: Rect(0, 0, 200, 10), direction: .leftToRight)
        XCTAssertEqual(fixed[1]?.width, 12, "a length it states wins over growing")
    }

    /// A separator is a stack's view; a menu's separator, like its entries, is one the menu draws.
    func testAMenusSeparatorIsViewlessAndASeparatorIsAView() {
        XCTAssertFalse(NodeType.viewlessTypes.contains(.separator))
        XCTAssertTrue(NodeType.viewlessTypes.contains(.menuSeparator))
        XCTAssertTrue(NodeType.menuTypes.contains(.menuSeparator))
        XCTAssertTrue(NodeType.viewlessTypes.contains(.menuItem))
        XCTAssertFalse(NodeType.viewlessTypes.contains(.space))
    }

    /// A vertical stack sets shown children one under another; a hidden one takes no room and no spacing.
    @MainActor
    func testAVerticalStackPlacesItsShownChildrenInOrder() {
        var centered = Child(width: 20, height: 10)
        centered.values.horizontal = 1
        let items = [Child(width: 20, height: 10), Child(width: 20, height: 10, shown: false), centered]

        let size = StackArithmetic.size(of: items, axis: .vertical, spacing: 5, padding: Insets(2), width: nil)
        let places = StackArithmetic.places(
            of: items, axis: .vertical, spacing: 5, padding: Insets(2), in: Rect(0, 0, 100, 50),
            direction: .leftToRight)

        XCTAssertEqual(size, LayoutSize(width: 24, height: 29))
        XCTAssertEqual(places[0], Rect(2, 2, 96, 10), "a filling child takes the slot's width")
        XCTAssertNil(places[1])
        XCTAssertEqual(places[2], Rect(40, 17, 20, 10), "a centered child stands in the middle")
    }

    // MARK: - Right to left

    /// A row laid out right to left fills from the right, its padding and margins on the other sides;
    /// spacing and sizes are the same.
    @MainActor
    func testARowRightToLeftFillsFromTheRight() {
        var first = Child(width: 20, height: 10)
        first.values.margin = Insets(start: 3, top: 0, end: 0, bottom: 0)
        let items = [first, Child(width: 30, height: 10)]

        let places = StackArithmetic.places(
            of: items, axis: .horizontal, spacing: 5, padding: Insets(start: 2, top: 0, end: 0, bottom: 0), in: Rect(0, 0, 100, 10),
            direction: .rightToLeft)

        XCTAssertEqual(places[0], Rect(75, 0, 20, 10), "the first child against the right edge, inside padding and margin")
        XCTAssertEqual(places[1], Rect(40, 0, 30, 10), "the next one to its left, the spacing between")
    }

    /// A column keeps its order down; a child aligned to its start stands at the right.
    @MainActor
    func testAColumnRightToLeftStandsItsStartAtTheRight() {
        var start = Child(width: 20, height: 10)
        start.values.horizontal = 0
        var end = Child(width: 20, height: 10)
        end.values.horizontal = 2

        let places = StackArithmetic.places(
            of: [start, end], axis: .vertical, spacing: 0, padding: Insets(0), in: Rect(0, 0, 100, 20),
            direction: .rightToLeft)

        XCTAssertEqual(places[0], Rect(80, 0, 20, 10))
        XCTAssertEqual(places[1], Rect(0, 10, 20, 10))
    }

    /// Right to left, a grid's column 0 is the rightmost, and its rows are where they were.
    @MainActor
    func testAGridRightToLeftStartsItsColumnsAtTheRight() {
        var first = Child(width: 10, height: 10)
        first.values.column = 0
        var second = Child(width: 10, height: 10)
        second.values.column = 1

        let places = GridArithmetic.places(
            of: [first, second], rows: [], columns: [.fixed(20), .fixed(30)],
            rowSpacing: 0, columnSpacing: 0, padding: Insets(0), in: Rect(0, 0, 100, 10),
            direction: .rightToLeft)

        XCTAssertEqual(places.map { $0?.x }, [80, 50])
    }

    /// Right to left, a ZStack's areas count from the right edge, and a child at its area's start stands at
    /// the area's right.
    @MainActor
    func testAZStackRightToLeftCountsItsAreasFromTheRight() {
        var badge = Child(width: 20, height: 10)
        badge.values.area = .absolute(10, 5, 40, 30)
        badge.values.horizontal = 0
        badge.values.vertical = 0
        var half = Child(width: 20, height: 10)
        half.values.area = .proportional(0, 0, 0.5, 1)

        let places = ZStackArithmetic.places(
            of: [badge, half], in: Rect(0, 0, 100, 50), padding: Insets(0), direction: .rightToLeft)

        XCTAssertEqual(places[0], Rect(70, 5, 20, 10))
        XCTAssertEqual(places[1], Rect(50, 0, 50, 50), "a proportion from 0 is the right half")
    }

    /// A picture beside a button's words leaves half of what the two and their gap do not fill on each side, so they
    /// stand together in the middle; nothing where they fill the room, or where the picture stands above or below.
    func testAButtonsPictureAndWordsStandTogetherInTheMiddle() {
        XCTAssertEqual(ButtonArithmetic.sideRoom(300, picture: 40, gap: 8, words: 52, position: .start), 100)
        XCTAssertEqual(ButtonArithmetic.sideRoom(300, picture: 40, gap: 8, words: 52, position: .end), 100)
        XCTAssertEqual(ButtonArithmetic.sideRoom(80, picture: 40, gap: 8, words: 52, position: .start), 0, "too narrow")
        XCTAssertEqual(ButtonArithmetic.sideRoom(300, picture: 40, gap: 8, words: 52, position: .top), 0)
        XCTAssertEqual(ButtonArithmetic.sideRoom(300, picture: 40, gap: 8, words: 52, position: .bottom), 0)
    }

    /// One child and its margin turn with the room; left to right is the default, and changes nothing.
    @MainActor
    func testOneChildRightToLeftTurnsWithItsRoom() {
        var child = Child(width: 20, height: 10)
        child.values.horizontal = 0
        child.values.margin = Insets(start: 4, top: 0, end: 0, bottom: 0)

        let room = Rect(0, 0, 100, 10)
        XCTAssertEqual(SingleChildArithmetic.place(of: child, in: room, direction: .rightToLeft), Rect(76, 0, 20, 10))
        XCTAssertEqual(SingleChildArithmetic.place(of: child, in: room, direction: .leftToRight), Rect(4, 0, 20, 10))
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
            rowSpacing: 0, columnSpacing: 0, padding: Insets(0), in: Rect(0, 0, 100, 10), direction: .leftToRight)

        XCTAssertEqual(places.map { $0?.x }, [0, 20, 50])
        XCTAssertEqual(places.map { $0?.width }, [20, 30, 50])
    }

    /// A ROW SHORT OF ROOM TAKES IT FROM ITS WORDS: the controls keep their width, and the words share what the
    /// others and the spacing leave, in proportion to their natural widths.
    @MainActor
    func testARowShortOfRoomTakesItFromItsWords() {
        let row = Self.row(title: 300, note: 100)

        let places = StackArithmetic.places(
            of: row, axis: .horizontal, spacing: 10, padding: Insets(0), in: Rect(0, 0, 300, 100),
            direction: .leftToRight)

        XCTAssertEqual(places.map { $0?.width }, [150, 50, 80], "200 left for the words, shared 3 to 1")
        XCTAssertEqual(places.map { $0?.x }, [0, 160, 220], "the button still on the row")
        XCTAssertEqual(places[0]?.height, 40, "the title wrapped to its 150")
    }

    /// A row with room enough keeps every child at its natural width.
    @MainActor
    func testARowWithRoomKeepsItsWordsWhole() {
        let places = StackArithmetic.places(
            of: Self.row(title: 300, note: 100), axis: .horizontal, spacing: 10, padding: Insets(0),
            in: Rect(0, 0, 600, 100), direction: .leftToRight)

        XCTAssertEqual(places.map { $0?.width }, [300, 100, 80])
    }

    /// A row measured for a width is as tall as its words wrapped to the width it gives them there, and its natural
    /// width is still its words on one line - the words placed at the width they were measured at, offered any room.
    @MainActor
    func testARowMeasuresItsWordsAtTheWidthItPlacesThem() {
        let measured = Self.row(title: 300, note: 100, offers: Offers())
        let placed = Self.row(title: 300, note: 100, offers: Offers())

        let size = StackArithmetic.size(of: measured, axis: .horizontal, spacing: 10, padding: Insets(0), width: 300)
        XCTAssertEqual(size, LayoutSize(width: 500, height: 40), "the title two lines at its 150")

        for room in stride(from: 100.0, through: 700, by: 23) {
            _ = StackArithmetic.size(of: measured, axis: .horizontal, spacing: 10, padding: Insets(0), width: room)
            _ = StackArithmetic.places(
                of: placed, axis: .horizontal, spacing: 10, padding: Insets(0), in: Rect(0, 0, room, 100),
                direction: .leftToRight)
            XCTAssertEqual(measured[0].offers?.widths.last, placed[0].offers?.widths.last, "the title at \(room)")
        }
    }

    /// A row of a title, a note and a button: the words wrap and yield, the button keeps its 80.
    @MainActor
    private static func row(title: Double, note: Double, offers: Offers? = nil) -> [Child] {
        var words = [Child(width: title, height: 20), Child(width: note, height: 20)]
        for index in words.indices {
            words[index].values.words = .bare
            words[index].values.vertical = 0
            words[index].wraps = true
        }
        words[0].offers = offers
        var button = Child(width: 80, height: 30)
        button.values.words = .boxed
        return words + [button]
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
            rowSpacing: 0, columnSpacing: 0, padding: Insets(0), in: Rect(0, 0, 120, 200), direction: .leftToRight)
        let size = GridArithmetic.size(
            of: [icon, words], rows: [.auto], columns: columns,
            rowSpacing: 0, columnSpacing: 0, padding: Insets(0), width: 120)

        XCTAssertEqual(places[1], Rect(20, 0, 100, 30), "three lines of words at the column's 100")
        XCTAssertEqual(size.height, 30)
        XCTAssertEqual(size.width, 320, "its natural width is still its words on one line")
    }

    /// A grid stands words wrapped as it measured them: in two proportional columns of unlike shares, offered a
    /// room narrower or wider than its natural width, and placed at that room or at its natural width, each row is
    /// as tall as the words it holds at the width they stand.
    @MainActor
    func testAGridPlacesItsWordsAtTheWidthItMeasuredThem() {
        var name = Child(width: 95, height: 20)
        name.wraps = true
        name.values.column = 1
        var words = Child(width: 300, height: 20)
        words.wraps = true
        words.values.column = 2
        let items = [Child(width: 100, height: 20), name, words]
        let columns: [GridLength] = [.fixed(140), .proportional(2), .proportional(3)]

        for room in stride(from: 400.0, through: 900, by: 25) {
            let size = GridArithmetic.size(
                of: items, rows: [.auto], columns: columns,
                rowSpacing: 0, columnSpacing: 0, padding: Insets(0), width: room)
            for width in [room, min(room, size.width)] {
                let places = GridArithmetic.places(
                    of: items, rows: [.auto], columns: columns, rowSpacing: 0, columnSpacing: 0,
                    padding: Insets(0), in: Rect(0, 0, width, size.height), direction: .leftToRight)
                XCTAssertEqual(
                    places.compactMap { $0?.height }.max(), size.height,
                    "offered \(room), placed at \(width): words as tall as measured")
            }
        }
    }

    /// A child spanning tracks asks its room of the tracks it spans: a grid measured with no room and placed at
    /// its size holds every child at least at its natural size - across proportional, automatic, and fixed and
    /// proportional columns, and down proportional rows.
    @MainActor
    func testAChildSpanningTracksAsksItsRoomOfThem() {
        func spanning(columns span: Int = 1, rows rowSpan: Int = 1, width: Double, height: Double) -> Child {
            var child = Child(width: width, height: height)
            child.wraps = true
            child.values.columnSpan = span
            child.values.rowSpan = rowSpan
            return child
        }
        var one = Child(width: 30, height: 20)
        one.values.row = 1
        let grids: [(name: String, items: [Child], rows: [GridLength], columns: [GridLength])] = [
            ("across proportional columns", [spanning(columns: 2, width: 100, height: 20)], [], [.fill, .proportional(3)]),
            ("across automatic columns", [spanning(columns: 2, width: 100, height: 20), one], [.auto, .auto], [.auto, .auto]),
            ("across a fixed and a proportional column", [spanning(columns: 2, width: 100, height: 20)], [], [.fixed(40), .fill]),
            ("down proportional rows", [spanning(rows: 2, width: 30, height: 80), one], [.fill, .fill], [.auto, .auto]),
        ]

        for grid in grids {
            let size = GridArithmetic.size(
                of: grid.items, rows: grid.rows, columns: grid.columns,
                rowSpacing: 10, columnSpacing: 14, padding: Insets(0))
            let places = GridArithmetic.places(
                of: grid.items, rows: grid.rows, columns: grid.columns, rowSpacing: 10, columnSpacing: 14,
                padding: Insets(0), in: Rect(0, 0, size.width, size.height), direction: .leftToRight)
            for (child, place) in zip(grid.items, places) {
                XCTAssertGreaterThanOrEqual(place?.width ?? 0, child.natural.width, grid.name)
                XCTAssertGreaterThanOrEqual(place?.height ?? 0, child.natural.height, grid.name)
            }
        }

        let alone = [spanning(columns: 2, width: 100, height: 20)]
        let size = GridArithmetic.size(
            of: alone, rows: [], columns: [.fill, .fill], rowSpacing: 0, columnSpacing: 14, padding: Insets(0),
            width: 360)
        XCTAssertEqual(size, LayoutSize(width: 100, height: 20), "one line, measured at its own width")
    }

    /// A ZStack stands each child in its area - the room within the padding, a rectangle in points, or one
    /// in fractions of the room - by the child's own alignments; a hidden one has no place.
    @MainActor
    func testAZStackStandsEachChildInItsArea() {
        var corner = Child(width: 20, height: 10)
        corner.values.horizontal = 2
        corner.values.vertical = 2
        var badge = Child(width: 20, height: 10)
        badge.values.area = .absolute(10, 5, 40, 30)
        badge.values.horizontal = 0
        badge.values.vertical = 0
        var half = Child(width: 20, height: 10)
        half.values.area = .proportional(0.5, 0, 0.5, 1)
        let items = [Child(width: 20, height: 10), corner, badge, half, Child(width: 20, height: 10, shown: false)]

        let places = ZStackArithmetic.places(
            of: items, in: Rect(0, 0, 100, 50), padding: Insets(4), direction: .leftToRight)

        XCTAssertEqual(places[0], Rect(4, 4, 92, 42), "the whole room within the padding")
        XCTAssertEqual(places[1], Rect(76, 36, 20, 10), "its natural size, at the room's far corner")
        XCTAssertEqual(places[2], Rect(14, 9, 20, 10), "points from the room's top left, the child at its start")
        XCTAssertEqual(places[3], Rect(50, 4, 46, 42), "the right half of the room")
        XCTAssertNil(places[4])
    }

    /// A ZStack needs the room its neediest child does: a rectangle in points to its far corner, a share
    /// big enough to hold the child, and anything else its natural size and margins.
    @MainActor
    func testAZStackMeasuresAsItsNeediestChild() {
        var margined = Child(width: 30, height: 10)
        margined.values.margin = Insets(start: 5, top: 0, end: 5, bottom: 0)
        var badge = Child(width: 20, height: 10)
        badge.values.area = .absolute(10, 5, 40, 30)
        var half = Child(width: 30, height: 20)
        half.values.area = .proportional(0.5, 0, 0.5, 0.5)

        XCTAssertEqual(ZStackArithmetic.size(of: [margined], padding: Insets(2), width: nil), LayoutSize(width: 44, height: 14))
        XCTAssertEqual(ZStackArithmetic.size(of: [badge], padding: Insets(0), width: nil), LayoutSize(width: 50, height: 35))
        XCTAssertEqual(
            ZStackArithmetic.size(of: [margined, badge, half], padding: Insets(0), width: nil),
            LayoutSize(width: 60, height: 40), "half of the room holds the child only in twice its size")
    }

    /// A phase layout has no size of its own: whatever its views need, it takes only its padding and the room its
    /// layout gives it.
    @MainActor
    func testAPhaseLayoutHasNoSizeOfItsOwn() {
        var badge = Child(width: 20, height: 10)
        badge.values.area = .absolute(10, 5, 40, 30)
        let views = [Child(width: 30, height: 20), badge]

        XCTAssertEqual(ZStackArithmetic.size(of: views, padding: Insets(0), width: 100, phaseLayout: true), LayoutSize(width: 0, height: 0))
        XCTAssertEqual(ZStackArithmetic.size(of: views, padding: Insets(2), width: nil, phaseLayout: true), LayoutSize(width: 4, height: 4))
    }

    /// A child that fills both ways takes the room within its margin, whatever it would measure.
    @MainActor
    func testASingleFillingChildTakesTheRoom() {
        var child = Child(width: 5, height: 5)
        child.values.margin = Insets(10)

        XCTAssertEqual(
            SingleChildArithmetic.place(of: child, in: Rect(0, 0, 100, 40), direction: .leftToRight),
            Rect(10, 10, 80, 20))
    }

    /// Every layout offers a child the room it stands in less the child's margin, once: the child answers for
    /// itself, and the layout adds the margin back.
    @MainActor
    func testEveryLayoutOffersAChildItsRoomLessItsMarginOnce() {
        let offers = Offers()
        var child = Child(width: 10, height: 10)
        child.values.margin = Insets(horizontal: 8, vertical: 4)
        child.values.horizontal = 0
        child.offers = offers
        var half = child
        half.values.area = .proportional(0, 0, 0.5, 1)
        let room = Rect(0, 0, 100, 100)

        func offered(_ layout: () -> Void) -> [Double?] {
            offers.widths = []
            layout()
            return offers.widths
        }

        XCTAssertEqual(offered {
            _ = StackArithmetic.size(of: [child], axis: .vertical, spacing: 0, padding: Insets(0), width: 100)
        }, [84], "a stack measured")
        XCTAssertEqual(offered {
            _ = StackArithmetic.places(
                of: [child], axis: .vertical, spacing: 0, padding: Insets(0), in: room, direction: .leftToRight)
        }, [84], "a stack placing")
        XCTAssertEqual(offered { _ = ZStackArithmetic.size(of: [child], padding: Insets(0), width: 100) }, [84], "a ZStack")
        XCTAssertEqual(offered { _ = ZStackArithmetic.size(of: [half], padding: Insets(0), width: 100) }, [34], "its area")
        XCTAssertEqual(offered { _ = SingleChildArithmetic.size(of: child, width: 100) }, [84], "one child")
        XCTAssertEqual(offered {
            _ = SingleChildArithmetic.place(of: child, in: room, direction: .leftToRight)
        }, [84], "one child placed")
        XCTAssertEqual(offered {
            _ = GridArithmetic.places(
                of: [child], rows: [.auto], columns: [], rowSpacing: 0, columnSpacing: 0, padding: Insets(0),
                in: room, direction: .leftToRight)
        }, [84, 84], "a grid's row and its place")
        XCTAssertEqual(offered {
            _ = ScrollArithmetic.contentSize(of: child, padding: Insets(0), orientation: .vertical, width: 100)
        }, [84], "a scroller's document")
    }

    /// Right to left, a scroller's child stands from the right of its document: its start, and its leading margin,
    /// at the right edge.
    @MainActor
    func testAScrollersChildRightToLeftStandsFromTheRight() {
        var child = Child(width: 20, height: 10)
        child.values.horizontal = 0
        child.values.vertical = 0
        child.values.margin = Insets(start: 5, top: 0, end: 0, bottom: 0)
        let viewport = LayoutSize(width: 100, height: 50)

        XCTAssertEqual(ScrollArithmetic.arrange(
            child, padding: Insets(0), orientation: .vertical, in: viewport, direction: .rightToLeft).place,
            Rect(x: 75, y: 0, width: 20, height: 10))
        XCTAssertEqual(ScrollArithmetic.arrange(
            child, padding: Insets(0), orientation: .vertical, in: viewport, direction: .leftToRight).place,
            Rect(x: 5, y: 0, width: 20, height: 10))
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

    /// Words measured without a width stand the same in any room at least as wide: a long listing in a scroller,
    /// laid out as wide as its document each frame a page widens, is measured once.
    @MainActor
    func testWordsMeasuredWithoutAWidthHoldInAnyWiderRoom() {
        let cache = MeasurementCache(holdsWhenWider: true)
        var measured = 0
        func size(_ width: Double?) -> LayoutSize {
            cache.size(offering: width) {
                measured += 1
                return LayoutSize(width: min(width ?? 537, 537), height: width.map { $0 < 537 ? 40 : 20 } ?? 20)
            }
        }

        XCTAssertEqual(size(nil), LayoutSize(width: 537, height: 20))
        XCTAssertEqual(size(756), LayoutSize(width: 537, height: 20))
        XCTAssertEqual(size(1024), LayoutSize(width: 537, height: 20))
        XCTAssertEqual(size(537), LayoutSize(width: 537, height: 20))
        XCTAssertEqual(measured, 1, "measured once, without a width")
        XCTAssertEqual(size(400), LayoutSize(width: 400, height: 40), "a narrower room breaks the words")
        XCTAssertEqual(measured, 2)
        XCTAssertEqual(
            MeasurementCache().size(offering: 756) { LayoutSize(width: 756, height: 1) }.width, 756,
            "a layout's size is its own at every width")
    }
}

/// A child of a stated natural size; one that wraps is as wide as that on one line, and a line taller for each
/// time it has to break to fit a narrower width.
private struct Child: LayoutChild {
    var values = LayoutValues()
    let natural: LayoutSize
    let isShown: Bool
    var wraps = false

    /// Where the widths it is offered are written; nil keeps none.
    var offers: Offers?

    init(width: Double, height: Double, shown: Bool = true) {
        natural = LayoutSize(width: width, height: height)
        isShown = shown
    }

    func size(offered width: Double?) -> LayoutSize {
        offers?.widths.append(width)
        if wraps, let width, width > 0, width < natural.width {
            return LayoutSize(width: width, height: natural.height * (natural.width / width).rounded(.up))
        }
        return LayoutSize(
            width: values.boundedWidth(values.width ?? natural.width),
            height: values.boundedHeight(values.height ?? natural.height))
    }
}

/// The widths a child was offered, in order.
@MainActor
private final class Offers {
    var widths: [Double?] = []
}
