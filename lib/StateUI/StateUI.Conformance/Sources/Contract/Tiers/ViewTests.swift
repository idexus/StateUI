// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ViewContract` on a host: where a view stands in its parent - its margin, its alignment, its area in a layered
/// stack, its cell in a grid - as the frame it reports says, StateUI's arithmetic alike on every host; and what it
/// hears of the user's hand - taps counted, a press shown in its pressed look, a screen reader's press, a press held,
/// a pan carrying its states and ending as a swipe, a pinch, the pointer coming, moving, pressing and going, a drag
/// and a drop; each case made for every element wearing the tier. And
/// where a view stands in its window as a scroller's or a list's scroll moves it, and from the safe area at its page's
/// corner; how a view of a motion layout moves as a body following its place; and what a hand does to a number a
/// motion layout's interaction names.
@_spi(Host) public enum ViewTests: ConformanceFamily {
    public static let name = "View"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ViewContract.self).flatMap { element in
            [
                margined(element), drawn(element), aligned(element), inArea(element), inCell(element), acrossCells(element),
                tapped(element), pressedAsAButton(element), longPressed(element), longPressedAfterItsTime(element), panned(element), moved(element), pressedByItself(element), taken(element), thrown(element), pressTakenAway(element), takenFromTheHand(element), swiped(element), pinched(element), rotated(element), pointed(element),
                dragged(element), droppedOn(element), filesDroppedOn(element), bodied(element),
            ]
        } + [
            scrolledInItsWindow, scrolledInAList, atItsPagesCorner, carriedToItsPlace, onAFirstBaseline, showsItsPress,
            pressedByAScreenReader,
        ] + layoutUnderTheHand
    }

    /// A view answering a tap is a button to assistive technology: a screen reader's press on it runs the handler a
    /// tap runs.
    @MainActor
    static var pressedByAScreenReader: ConformanceCase {
        ConformanceCase("HStack.aScreenReadersPressTapsIt", proves: [
            Covered(ViewContract.tapped, on: "HStack"),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    HStack { Text("Open details") }
                        .accessibilityLabel("Open details")
                        .onTapped { heard.values.append("tapped") }
                        .id("row")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            try s.perform(.accessibilityPress, on: s.element("row"))
            s.settle { heard.values == ["tapped"] }
            s.expect(heard.values, ["tapped"], "the screen reader's press runs the handler a tap runs")
        }
    }

    /// A view answering a tap is pressed as a button is: the look its visual state gives a pressed view stands while
    /// the press holds, and letting go gives its own back.
    @MainActor
    static var showsItsPress: ConformanceCase {
        ConformanceCase("ZStack.aPressShowsItsPressedLookWhileItHolds", proves: [
            Covered(ViewContract.tapped, on: "ZStack"),
        ], needs: [Covered(BackgroundElementContract.background, on: "ZStack")]) { s in
            s.start {
                VStack {
                    ZStack { Text("Row") }
                        .width(80)
                        .height(40)
                        .background(.steelBlue)
                        .visualState(.pressed) { $0.background(.firebrick) }
                        .onTapped {}
                        .id("row")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let row = try s.element("row")
            let background = { try s.held(BackgroundElementContract.background, on: row) }
            try s.settle { try background() == .color(.steelBlue) }

            try s.perform(.pressDown(at: Point(x: 40, y: 20)), on: row)
            try s.settle { try background() == .color(.firebrick) }
            s.expect(try background(), .color(.firebrick), "its pressed look while the press holds")

            try s.perform(.lift(at: Point(x: 40, y: 20)), on: row)
            try s.settle { try background() == .color(.steelBlue) }
            s.expect(try background(), .color(.steelBlue), "its own look again")
        }
    }

    /// A scroll moves where a view stands in its window, though nothing lays it out anew: its place in its parent
    /// stays.
    @MainActor
    static var scrolledInItsWindow: ConformanceCase {
        ConformanceCase("aScrollMovesWhereAViewStandsInItsWindow", proves: [
            Covered(ViewContract.layoutFrameChanged, on: "Rectangle"),
        ], needs: [Covered(ScrollViewContract.self)]) { s in
            let clock = TestClock()
            let frames = Received<[Double]>()
            s.start(clock: clock) {
                VStack {
                    ScrollView {
                        VStack {
                            Rectangle()
                                .fill(.red)
                                .width(120)
                                .height(60)
                                .onEvent(ViewContract.layoutFrameChanged) { frames.values.append($0) }
                            Rectangle()
                                .fill(.blue)
                                .width(120)
                                .height(2000)
                        }
                        .horizontalAlignment(.start)
                    }
                    .width(200).height(300).id("scroller")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { !frames.values.isEmpty }
            s.frames(of: clock, until: 400)
            let before = frames.values.last ?? []

            try s.perform(.scroll(to: Point(x: 0, y: 200)), on: s.element("scroller"))
            s.turn()
            s.frames(of: clock, until: 800)
            let moved = FrameReport.inWindow(before, movedUp: 200)
            s.settle { frames.values.last.map(FrameReport.inWindow) == moved }

            s.expect(frames.values.last.map(FrameReport.inWindow), moved, "200 higher in its window")
            s.expect(frames.values.last.map(FrameReport.place), FrameReport.place(before), "where it was in its parent")
        }
    }

    /// A list's scroll moves where an item's view stands in its window, the item's place in its cell kept.
    @MainActor
    static var scrolledInAList: ConformanceCase {
        ConformanceCase("aScrollMovesWhereAnItemStandsInItsWindow", proves: [
            Covered(ViewContract.layoutFrameChanged, on: "Rectangle"),
        ], needs: [Covered(ItemsViewContract.self)]) { s in
            let clock = TestClock()
            let frames = Received<[Double]>()
            s.start(clock: clock) {
                VStack {
                    ItemsView(0..<100) { item in
                        Rectangle()
                            .fill(item == 2 ? .red : .blue)
                            .width(120)
                            .height(60)
                            .onEvent(ViewContract.layoutFrameChanged) { if item == 2 { frames.values.append($0) } }
                    }
                    .width(200).height(300).id("list")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { !frames.values.isEmpty }
            s.frames(of: clock, until: 400)
            let before = frames.values.last ?? []

            try s.perform(.scroll(to: Point(x: 0, y: 100)), on: s.element("list"))
            s.turn()
            s.frames(of: clock, until: 800)
            let moved = FrameReport.inWindow(before, movedUp: 100)
            s.settle { frames.values.last.map(FrameReport.inWindow) == moved }

            s.expect(frames.values.last.map(FrameReport.inWindow), moved, "100 higher in its window")
            s.expect(frames.values.last.map(FrameReport.place), FrameReport.place(before), "where it was in its cell")
        }
    }

    /// The safe area is where a page's content may stand: a view at its page's top corner, under the stack's bar,
    /// stands at the safe area's corner.
    @MainActor
    static var atItsPagesCorner: ConformanceCase {
        ConformanceCase("aViewAtItsPagesCornerStandsAtTheSafeAreasCorner", proves: [
            Covered(ViewContract.layoutFrameChanged, on: "Rectangle"),
        ], needs: [Covered(NavigationStackContract.self)]) { s in
            let frames = Received<[Double]>()
            s.start {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    VStack {
                        Rectangle()
                            .fill(.red)
                            .width(120)
                            .height(60)
                            .onEvent(ViewContract.layoutFrameChanged) { frames.values.append($0) }
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                    .pageTitle("Corner")
                } destination: { _ in Text("Below") }
            }

            s.settle { frames.values.last.map(FrameReport.inContent) == [0, 0] }
            s.expect(frames.values.last.map(FrameReport.inContent), [0, 0], "at the safe area's corner, under the bar")
        }
    }

    /// Two lines of words of other sizes in a row, each on its first baseline, rest on one line: the smaller stands
    /// lower by the larger's taller rise above the line - far more than it stands above the larger's foot, which a
    /// row centering them would give alike.
    @MainActor
    static var onAFirstBaseline: ConformanceCase {
        ConformanceCase("wordsOfOtherSizesInARowRestOnOneFirstBaseline", proves: [
            Covered(ViewContract.verticalAlignment, on: "Text"),
        ], needs: [Covered(HStackContract.self)]) { s in
            s.start {
                VStack {
                    HStack {
                        Text("Total").fontSize(12).verticalAlignment(.firstBaseline).id("small")
                        Text("120").fontSize(40).verticalAlignment(.firstBaseline).id("large")
                    }
                    .spacing(8)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let places = { (try? s.place(of: s.element("small")), try? s.place(of: s.element("large"))) }
            s.settle { places().0.map { $0.height > 0 } ?? false }
            guard case let (small?, large?) = places() else { return s.expect(false, true, "both placed") }

            let above = small.y - large.y
            let below = (large.y + large.height) - (small.y + small.height)
            // The smaller's foot stands within the larger's, never past it, and its top below the larger's top.
            s.expect(below >= -0.5 && above > 0 && above < large.height, true,
                     "within the larger's frame: \(above) above, \(below) below")
            s.expect(above > 2 * below, true, "lower by the larger's rise: \(above) above, \(below) below")
        }
    }

    /// A view of a motion layout following its place as a body lags behind it as the phase moves it, passes it on a
    /// spring damped below 1, and settles onto it.
    @MainActor
    static func bodied(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aBodyFollowingItsPlaceLagsAndSettles", proves: [
            Covered(ViewContract.layoutBody, on: element),
        ], needs: [Covered(MotionLayoutContract.self), Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let clock = TestClock()
            let phase = State(wrappedValue: 0.0, motion: .none)
            let laid = Received<Double>()
            let body = LayoutBody.followsLayout(response: .milliseconds(400), damping: 0.5)
            s.start(clock: clock) {
                VStack {
                    MotionLayout([0], parameters: phase.projectedValue) { _ in
                        Specimens.view(element, [
                            Write(VisualElementContract.width, 40), Write(VisualElementContract.height, 40),
                            Write(ViewContract.layoutBody, body),
                        ])
                    } placements: { _, at in
                        laid.values.append(at)
                        return [Placement(Rect(x: at * 100, y: 0, width: 40, height: 40))]
                    }
                    .width(200).height(40)
                    // The place leaps a hundred on.
                    Button("Leap").onClicked { phase.wrappedValue = 1 }.id("leap")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { laid.values.last == 0 }
            // Where the host stands it once its frames have laid it out.
            while clock.now < 200 {
                clock.now += 16
                s.frame()
            }
            let start = try s.place(of: s.element("specimen")).x
            let moved = { (try? s.place(of: s.element("specimen")).x).map { $0 - start } ?? .nan }

            // The body is carried by its spring after its place.
            try s.perform(.activate, on: s.element("leap"))
            s.settle { laid.values.last == 1 }
            var (first, farthest) = (moved(), 0.0)
            while clock.now < 3_200 {
                clock.now += 16
                s.frame()
                if first.isNaN { first = moved() }
                farthest = max(farthest, moved())
            }
            s.expect(first < 50, true, "behind its place as it leaps")
            s.expect(farthest > 101, true, "past it, on its spring")
            s.expect(abs(moved() - 100) < 0.5, true, "and onto it")
        }
    }

    /// A view stands its margin in from its parent's corner.
    @MainActor
    static func margined(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsInsideItsMargin", proves: [
            Covered(ViewContract.margin, on: element), Covered(ViewContract.layoutFrameChanged, on: element),
        ]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    reporting(element, frames, [
                        Write(VisualElementContract.width, 120), Write(VisualElementContract.height, 40),
                        Write(ViewContract.margin, Insets(start: 10, top: 6, end: 0, bottom: 0)),
                    ])
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(FrameReport.place) == [10, 6, 120, 40] }
            s.expect(frames.values.last.map(FrameReport.place), [10, 6, 120, 40], "x, y, width, height in its parent")
        }
    }

    /// A view's two rectangles: a transform of its own moves the one around what is drawn, its corner in the
    /// window with it, and leaves where its layout puts it.
    @MainActor
    static func drawn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).itsDrawnFrameFollowsItsTransform", proves: [
            Covered(ViewContract.presentationFrameChanged, on: element),
        ], needs: [Covered(ViewContract.layoutFrameChanged, on: element)]) { s in
            let placed = Received<[Double]>()
            let drawn = Received<[Double]>()
            s.start {
                VStack {
                    reporting(element, placed, [
                        Write(VisualElementContract.width, 120), Write(VisualElementContract.height, 40),
                        Write(ViewContract.margin, Insets(start: 80, top: 40, end: 0, bottom: 0)),
                        Write(VisualElementContract.scale, 1.5), Write(VisualElementContract.translationX, 10),
                        Hear(ViewContract.presentationFrameChanged) { numbers in drawn.values.append(numbers) },
                    ])
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle {
                drawn.values.last.map(FrameReport.place) == [60, 30, 180, 60]
                    && placed.values.last.map(FrameReport.place) == [80, 40, 120, 40]
            }
            s.expect(
                drawn.values.last.map(FrameReport.place), [60, 30, 180, 60],
                "half as large again about its middle, ten across")
            s.expect(placed.values.last.map(FrameReport.place), [80, 40, 120, 40], "where its layout puts it")
            let corner = placed.values.last.map(FrameReport.inWindow) ?? []
            s.expect(
                drawn.values.last.map(FrameReport.inWindow), corner.count == 2 ? [corner[0] - 20, corner[1] - 10] : [],
                "its corner in the window with it")
        }
    }

    /// A view its layout's motion carries to a new place: the layout's stage hears where it is going, alone and
    /// before the view is there; the presentation's hears the way.
    @MainActor
    static var carriedToItsPlace: ConformanceCase {
        ConformanceCase("aViewCarriedToItsPlaceSaysItsWayToThePresentationAlone", proves: [
            Covered(ViewContract.layoutFrameChanged, on: "Rectangle"),
            Covered(ViewContract.presentationFrameChanged, on: "Rectangle"),
        ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let clock = TestClock()
            let far = State(wrappedValue: false)
            let placed = Received<[Double]>()
            let drawn = Received<[Double]>()
            s.start(clock: clock) {
                VStack {
                    Carried(far: far.projectedValue, placed: placed, drawn: drawn)
                    Button("Move").onClicked { far.wrappedValue = true }.id("move")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { placed.values.last.map(FrameReport.place) == [0, 0, 40, 40] }
            s.frames(of: clock, until: 200)
            let (heard, seen) = (placed.values.count, drawn.values.count)

            // The clock stands: the change is rendered, and the view cannot have moved.
            try s.perform(.activate, on: s.element("move"))
            s.settle { placed.values.last.map(FrameReport.place) == [160, 0, 40, 40] }
            let early = try s.place(of: s.element("specimen"))
            s.expect(placed.values.last.map(FrameReport.place), [160, 0, 40, 40], "where it is going, said")
            s.expect(early.x < 150, true, "before it is there: \(early.x)")

            s.frames(of: clock, until: 1_400)
            s.settle { drawn.values.last.map(FrameReport.place) == [160, 0, 40, 40] }
            let places = Set(placed.values.dropFirst(heard).map(FrameReport.place))
            let way = drawn.values.dropFirst(seen).map { $0.first ?? 0 }
            s.expect(places, [[160, 0, 40, 40]], "the layout's stage hears its destination alone")
            s.expect(
                way.filter { $0 > 1 && $0 < 159 }.count >= 3, true,
                "the presentation's hears the way: \(way.count) heard, \(way.prefix(6).map { ($0 * 10).rounded() / 10 })")
            s.expect(way == way.sorted(), true, "each place further than the last")
            s.expect(drawn.values.last.map(FrameReport.place), [160, 0, 40, 40], "and where it came to")
        }
    }

    /// A view stands where its alignment puts it in the room its parent gives it.
    @MainActor
    static func aligned(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsWhereItsAlignmentPutsIt", proves: [
            Covered(ViewContract.horizontalAlignment, on: element), Covered(ViewContract.verticalAlignment, on: element),
            Covered(ViewContract.layoutFrameChanged, on: element),
        ]) { s in
            let across = Received<[Double]>()
            let down = Received<[Double]>()
            s.start {
                VStack {
                    VStack {
                        reporting(element, across, [
                            Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 20),
                            Write(ViewContract.horizontalAlignment, Alignment.end),
                        ], id: "across")
                    }
                    .width(300)
                    HStack {
                        reporting(element, down, [
                            Write(VisualElementContract.width, 20), Write(VisualElementContract.height, 40),
                            Write(ViewContract.verticalAlignment, Alignment.end),
                        ], id: "down")
                    }
                    .height(100)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { across.values.last.map(FrameReport.place)?[0] == 200 && down.values.last.map(FrameReport.place)?[1] == 60 }
            s.expect(across.values.last.map(FrameReport.place)?[0], 200, "at the end of a room 300 wide")
            s.expect(down.values.last.map(FrameReport.place)?[1], 60, "at the end of a room 100 high")
        }
    }

    /// A view in a layered stack stands in its area as in any slot: filling it, in points and then in shares of the
    /// room; at its own size where its alignments say, in an area reaching past the room's top left corner, and that
    /// turned about the room's middle right to left; and no larger than its area, its most stopping it short in the
    /// middle and its least giving way to it. It fills its place across, whatever it does unsaid - a link stands at
    /// its words.
    @MainActor
    static func inArea(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsInItsArea", proves: [
            Covered(ViewContract.area, on: element), Covered(ViewContract.layoutFrameChanged, on: element),
        ], needs: [
            Covered(ClickElementContract.clicked, on: ButtonContract.self),
            Covered(ViewContract.horizontalAlignment, on: element), Covered(ViewContract.verticalAlignment, on: element),
            Covered(VisualElementContract.width, on: element), Covered(VisualElementContract.height, on: element),
            Covered(VisualElementContract.maximumHeight, on: element),
            Covered(VisualElementContract.minimumWidth, on: element),
            Covered(VisualElementContract.layoutDirection, on: "ZStack"),
        ]) { s in
            let step = State(wrappedValue: 0)
            let frames = Received<[Double]>()
            let worn: [[any Worn]] = [
                [Write(ViewContract.area, Area.absolute(Rect(x: 10, y: 20, width: 30, height: 40))),
                 Write(ViewContract.horizontalAlignment, Alignment.fill)],
                [Write(ViewContract.area, Area.proportional(Rect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))),
                 Write(ViewContract.horizontalAlignment, Alignment.fill)],
                [Write(ViewContract.area, Area.absolute(Rect(x: -10, y: -5, width: 80, height: 60))),
                 Write(VisualElementContract.width, 30), Write(VisualElementContract.height, 40),
                 Write(ViewContract.horizontalAlignment, Alignment.start), Write(ViewContract.verticalAlignment, Alignment.end)],
                [Write(ViewContract.area, Area.absolute(Rect(x: -10, y: -5, width: 80, height: 60))),
                 Write(VisualElementContract.width, 30), Write(VisualElementContract.height, 40),
                 Write(ViewContract.horizontalAlignment, Alignment.start), Write(ViewContract.verticalAlignment, Alignment.end)],
                [Write(ViewContract.area, Area.absolute(Rect(x: 20, y: 30, width: 40, height: 40))),
                 Write(VisualElementContract.width, 60), Write(VisualElementContract.maximumHeight, 20),
                 Write(ViewContract.horizontalAlignment, Alignment.start)],
                [Write(ViewContract.area, Area.absolute(Rect(x: 0, y: 0, width: 40, height: 40))),
                 Write(VisualElementContract.minimumWidth, 60), Write(ViewContract.horizontalAlignment, Alignment.start)],
            ]
            s.start {
                VStack {
                    ZStack {
                        reporting(element, frames, worn[step.wrappedValue])
                    }
                    .width(200).height(200)
                    .layoutDirection(step.wrappedValue == 3 ? .rightToLeft : .leftToRight)
                    Button("Next").onClicked { step.wrappedValue += 1 }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            let places: [([Double], String)] = [
                ([10, 20, 30, 40], "filling it, in points"),
                ([100, 100, 100, 100], "its room's lower right quarter"),
                ([-10, 15, 30, 40], "its own size at its start and its foot, the area past the room's corner"),
                ([180, 15, 30, 40], "the same turned about the room's middle right to left"),
                ([20, 40, 40, 20], "no wider than its area, its most short of it in the middle"),
                ([0, 0, 40, 40], "its least giving way to its area"),
            ]
            for (index, (place, said)) in places.enumerated() {
                if index > 0 { try s.perform(.activate, on: s.element("change")) }
                s.settle { frames.values.last.map(FrameReport.place) == place }
                s.expect(frames.values.last.map(FrameReport.place), place, said)
            }
        }
    }

    /// A view in a grid stands in the cell its column and row name, filling it across whatever it does unsaid.
    @MainActor
    static func inCell(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsInItsCell", proves: [
            Covered(ViewContract.gridColumn, on: element), Covered(ViewContract.gridRow, on: element),
            Covered(ViewContract.layoutFrameChanged, on: element),
        ], needs: [Covered(ViewContract.horizontalAlignment, on: element)]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    Grid {
                        reporting(element, frames, [
                            Write(ViewContract.gridColumn, 1), Write(ViewContract.gridRow, 1),
                            Write(ViewContract.horizontalAlignment, Alignment.fill),
                        ])
                    }
                    .columns(.fixed(40), .fixed(60))
                    .rows(.fixed(30), .fixed(50))
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(FrameReport.place) == [40, 30, 60, 50] }
            s.expect(frames.values.last.map(FrameReport.place), [40, 30, 60, 50])
        }
    }

    /// A view in a grid spanning columns and rows stands across them, filling them across whatever it does unsaid.
    @MainActor
    static func acrossCells(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsAcrossTheCellsItSpans", proves: [
            Covered(ViewContract.gridColumnSpan, on: element), Covered(ViewContract.gridRowSpan, on: element),
            Covered(ViewContract.layoutFrameChanged, on: element),
        ], needs: [Covered(ViewContract.horizontalAlignment, on: element)]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    Grid {
                        reporting(element, frames, [
                            Write(ViewContract.gridColumnSpan, 2), Write(ViewContract.gridRowSpan, 2),
                            Write(ViewContract.horizontalAlignment, Alignment.fill),
                        ])
                    }
                    .columns(.fixed(40), .fixed(60))
                    .rows(.fixed(30), .fixed(50))
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(FrameReport.place) == [0, 0, 100, 80] }
            s.expect(frames.values.last.map(FrameReport.place), [0, 0, 100, 80])
        }
    }

    /// A quick run of taps is heard once it reaches the count the view asks for, and not before.
    @MainActor
    static func tapped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aRunOfTapsIsHeardAtItsCount", proves: [
            Covered(ViewContract.tapped, on: element), Covered(ViewContract.tapCount, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.tapCount, 2), HearDone(ViewContract.tapped) { heard.values.append("tapped") },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.tap(count: 1), on: view)
            s.turn()
            s.expect(heard.values, [], "one tap is not the two it asks for")
            try s.perform(.tap(count: 2), on: view)
            s.settle { heard.values == ["tapped"] }
            s.expect(heard.values, ["tapped"], "two are")
        }
    }

    /// A press taps as a button does: let go away from the view it taps nothing, and back where it went down before
    /// it lets go it taps.
    @MainActor
    static func pressedAsAButton(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPressTapsWhereItLetsGoOverTheView", proves: [
            Covered(ViewContract.tapped, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        HearDone(ViewContract.tapped) { heard.values.append("tapped") },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.pressDown(at: Point(x: 40, y: 20)), on: view)
            try s.perform(.drag(to: Point(x: 40, y: 100)), on: view)
            try s.perform(.lift(at: Point(x: 40, y: 100)), on: view)
            s.turn()
            s.expect(heard.values, [], "let go away from the view: no tap")

            try s.perform(.pressDown(at: Point(x: 40, y: 20)), on: view)
            try s.perform(.drag(to: Point(x: 40, y: 100)), on: view)
            try s.perform(.drag(to: Point(x: 40, y: 20)), on: view)
            try s.perform(.lift(at: Point(x: 40, y: 20)), on: view)
            s.settle { heard.values == ["tapped"] }
            s.expect(heard.values, ["tapped"], "back over the view before it lets go: a tap")
        }
    }

    /// A press held is heard as held, and its release is no tap; a tap is no long press.
    @MainActor
    static func longPressed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aLongPressIsHeardAndNoTap", proves: [
            Covered(ViewContract.longPressed, on: element),
        ], needs: [Covered(ViewContract.tapped, on: element)]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        HearDone(ViewContract.longPressed) { heard.values.append("longPressed") },
                        HearDone(ViewContract.tapped) { heard.values.append("tapped") },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.longPress, on: view)
            s.settle { heard.values.contains("longPressed") }
            s.expect(heard.values, ["longPressed"], "held, and its release no tap")
            try s.perform(.tap(count: 1), on: view)
            s.turn()
            s.expect(heard.values.filter { $0 == "longPressed" }, ["longPressed"], "a tap is no long press")
        }
    }

    /// A view's long press waits the time the tree gives it, as its native recognizer holds it, and the time the tree
    /// changes it to.
    @MainActor
    static func longPressedAfterItsTime(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aLongPressWaitsItsTime", proves: [
            Covered(ViewContract.longPressDuration, on: element),
        ], needs: [Covered(ViewContract.longPressed, on: element), Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
            let long = State(wrappedValue: false)
            s.start {
                VStack {
                    Button("Longer").onClicked { long.wrappedValue = true }.id("change")
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.longPressDuration, long.wrappedValue ? 900 : 700), HearDone(ViewContract.longPressed) {},
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")
            try s.settle { try s.held(ViewContract.longPressDuration, on: view) == 700 }
            s.expect(try s.held(ViewContract.longPressDuration, on: view), 700, "the time the tree gave")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.held(ViewContract.longPressDuration, on: view) == 900 }
            s.expect(try s.held(ViewContract.longPressDuration, on: view), 900, "the time the tree changed it to")
        }
    }

    /// A press dragged across a view is heard as it starts, runs and ends - each report how far it came and how fast
    /// it goes, its end where it reached, where the press is in the view's own points. The view stands away from the
    /// window's corner, so a point of the window is no point of the view.
    @MainActor
    static func panned(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPanIsHeardFromItsStartToItsEnd", proves: [
            Covered(ViewContract.panUpdated, on: element), Covered(ViewContract.panTouchCount, on: element),
        ], needs: [Covered(PaddingElementContract.padding, on: "VStack")]) { s in
            let heard = Received<String>()
            let lifted = Received<Point>()
            let began = Received<Point>()
            s.start(clock: TestClock()) {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Write(ViewContract.panTouchCount, 1),
                        HearFour(ViewContract.panUpdated) { phase, total, velocity, at in
                            heard.values.append("\(phase) \(Int(total.x)) \(Int(total.y))")
                            began.values.append(Point(x: at.x - total.x, y: at.y - total.y))
                            if phase == .ended { lifted.values.append(velocity) }
                        },
                    ])
                }
                .padding(start: 120, top: 120, end: 0, bottom: 0)
                .horizontalAlignment(.start)
            }

            try s.perform(.pan(by: Point(x: -60, y: 20)), on: s.element("specimen"))
            s.settle { heard.values.last?.hasPrefix("ended") == true }
            s.expect(heard.values.first, "began 0 0", "heard as it begins")
            s.expect(heard.values.contains("changed -60 20"), true, "changed, with how far it went")
            s.expect(heard.values.last, "ended -60 20", "and as it ends, where it reached")
            // How fast is the case's clock's - every step at one time, read over a frame; which way is the hand's.
            s.expect(lifted.values.last.map { $0.x < 0 && $0.y > 0 }, true, "lifted going left and down")
            // Where the press is, less how far it came, is where it began - one place, on the view.
            let start = began.values.first ?? Point(x: -1, y: -1)
            s.expect(began.values.allSatisfy { abs($0.x - start.x) < 1 && abs($0.y - start.y) < 1 }, true,
                     "where the press is moves with it: \(began.values)")
            s.expect((0...100).contains(start.x) && (0...100).contains(start.y), true,
                     "it began on the view, in its own points: \(start)")
        }
    }

    /// The hand over a view moves the state its interaction names - a point a point, the state nothing draws
    /// carried for the hand alone - and let go still, leaves it where it took it.
    @MainActor
    static func moved(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theHandMovesTheStateItsInteractionNames", proves: [
            Covered(ViewContract.interaction, on: element),
        ]) { s in
            let (clock, x) = (TestClock(), State(wrappedValue: 10.0))
            s.start(clock: clock) {
                VStack {
                    Opened.moved(Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                    ]), across: x.projectedValue)
                }
                .horizontalAlignment(.start)
            }
            s.frames(of: clock, until: 64)

            try s.perform(.sweep(by: Point(x: -60, y: 0), speed: .zero), on: s.element("specimen"))
            s.frames(of: clock, until: clock.now + 320)
            s.expect(x.wrappedValue, -50, "the state moved as far as the hand went, and left there")
            s.expect(x.projectedValue.journey.sample?.value, -50, "shown there, standing still")
        }
    }

    /// A press on a view saying its own press draws the view as its effect answers while it stands, and where its
    /// layout puts it once it lifts: no tap comes of it, and no state moves.
    @MainActor
    static func pressedByItself(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPressDrawsItAsItsEffectAnswers", proves: [
            Covered(ViewContract.interaction, on: element),
        ], needs: [Covered(ViewContract.presentationFrameChanged, on: element)]) { s in
            let (clock, drawn) = (TestClock(), Received<[Double]>())
            s.start(clock: clock) {
                VStack {
                    Opened.pressed(Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Hear(ViewContract.presentationFrameChanged) { numbers in drawn.values.append(numbers) },
                    ]))
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100] }
            let view = try s.element("specimen")

            try s.perform(.pressDown(at: Point(x: 50, y: 50)), on: view)
            s.frames(of: clock, until: clock.now + 48)
            s.settle { drawn.values.last.map(FrameReport.place) == [12, 0, 100, 100] }
            s.expect(drawn.values.last.map(FrameReport.place), [12, 0, 100, 100], "drawn as its effect answers")

            try s.perform(.lift(at: Point(x: 50, y: 50)), on: view)
            s.frames(of: clock, until: clock.now + 48)
            s.settle { drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100] }
            s.expect(drawn.values.last.map(FrameReport.place), [0, 0, 100, 100], "where its layout puts it again")
        }
    }

    /// The hand takes a view saying its own drag: the view stays under the hand as far as it goes, and stands
    /// where its layout puts it once let go.
    @MainActor
    static func taken(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theHandTakesTheViewItself", proves: [
            Covered(ViewContract.interaction, on: element),
        ], needs: [Covered(ViewContract.presentationFrameChanged, on: element)]) { s in
            let (clock, drawn) = (TestClock(), Received<[Double]>())
            s.start(clock: clock) {
                VStack {
                    Opened.taken(Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Hear(ViewContract.presentationFrameChanged) { numbers in drawn.values.append(numbers) },
                    ]))
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100] }
            let view = try s.element("specimen")

            try s.perform(.pressDown(at: Point(x: 50, y: 50)), on: view)
            try s.perform(.drag(to: Point(x: 80, y: 70)), on: view)
            s.frames(of: clock, until: clock.now + 48)
            s.settle { drawn.values.last.map(FrameReport.place) == [30, 20, 100, 100] }
            s.expect(drawn.values.last.map(FrameReport.place), [30, 20, 100, 100], "under the hand")

            try s.perform(.lift(at: Point(x: 80, y: 70)), on: view)
            s.frames(of: clock, until: clock.now + 48)
            s.settle { drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100] }
            s.expect(drawn.values.last.map(FrameReport.place), [0, 0, 100, 100], "let go: where its layout puts it")
        }
    }

    /// A view whose drag says a dismissal, thrown past its threshold, flies on out of the room that holds it and is
    /// told once it has left - the way it went - and, nobody removing it, stands where its layout puts it again.
    @MainActor
    static func thrown(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aViewThrownAwayIsToldAndComesBackWhereNobodyRemovesIt", proves: [
            Covered(ViewContract.dismissed, on: element),
        ], needs: [
            Covered(ViewContract.interaction, on: element), Covered(ViewContract.presentationFrameChanged, on: element),
        ]) { s in
            let (clock, drawn, told) = (TestClock(), Received<[Double]>(), Received<String>())
            s.start(clock: clock) {
                VStack {
                    Opened.thrown(Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Hear(ViewContract.presentationFrameChanged) { numbers in drawn.values.append(numbers) },
                        HearTwo(ViewContract.dismissed) { direction, _ in told.values.append("\(direction)") },
                    ]))
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100] }
            let view = try s.element("specimen")

            // Forty points up, past its thirty: let go, it flies on until none of it is left in the room.
            try s.perform(.pressDown(at: Point(x: 50, y: 50)), on: view)
            try s.perform(.drag(to: Point(x: 50, y: 10)), on: view)
            s.frames(of: clock, until: clock.now + 48)
            s.turn()
            s.expect(told.values, [], "under the hand: nothing told")
            try s.perform(.lift(at: Point(x: 50, y: 10)), on: view)
            s.frames(of: clock, until: clock.now + 1_000)
            s.settle { told.values == ["up"] }
            s.expect(told.values, ["up"], "told once it has left the room, the way it went")

            // Its handler ended out of any frame: the frames after it show the view back.
            s.settle {
                clock.now += 16
                s.frame()
                return drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100]
            }
            s.expect(drawn.values.last.map(FrameReport.place), [0, 0, 100, 100], "nobody removed it: at its place again")
        }
    }

    /// A press the platform takes away taps nothing, though it stood over the view; the next press taps as ever.
    @MainActor
    static func pressTakenAway(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPressTakenAwayTapsNothing", proves: [
            Covered(ViewContract.tapped, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        HearDone(ViewContract.tapped) { heard.values.append("tapped") },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.pressDown(at: Point(x: 40, y: 20)), on: view)
            try s.perform(.cancelInteraction, on: view)
            s.turn()
            s.expect(heard.values, [], "taken away over the view: no tap")

            try s.perform(.pressDown(at: Point(x: 40, y: 20)), on: view)
            try s.perform(.lift(at: Point(x: 40, y: 20)), on: view)
            s.settle { heard.values == ["tapped"] }
            s.expect(heard.values, ["tapped"], "and the next press taps")
        }
    }

    /// A view the platform takes from the hand past its dismissal's threshold is not dismissed, as one let go
    /// there is: it stands where its layout puts it again, and nobody is told.
    @MainActor
    static func takenFromTheHand(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aViewTakenFromTheHandIsNotDismissed", proves: [
            Covered(ViewContract.interaction, on: element),
        ], needs: [
            Covered(ViewContract.dismissed, on: element), Covered(ViewContract.presentationFrameChanged, on: element),
        ]) { s in
            let (clock, drawn, told) = (TestClock(), Received<[Double]>(), Received<String>())
            s.start(clock: clock) {
                VStack {
                    Opened.thrown(Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Hear(ViewContract.presentationFrameChanged) { numbers in drawn.values.append(numbers) },
                        HearTwo(ViewContract.dismissed) { direction, _ in told.values.append("\(direction)") },
                    ]))
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            s.settle { drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100] }
            let view = try s.element("specimen")

            // Forty points up, past its thirty - where a hand letting go dismisses it.
            try s.perform(.pressDown(at: Point(x: 50, y: 50)), on: view)
            try s.perform(.drag(to: Point(x: 50, y: 10)), on: view)
            s.frames(of: clock, until: clock.now + 48)
            s.settle { drawn.values.last.map(FrameReport.place) == [0, -40, 100, 100] }
            s.expect(drawn.values.last.map(FrameReport.place), [0, -40, 100, 100], "under the hand, past its threshold")

            try s.perform(.cancelInteraction, on: view)
            s.frames(of: clock, until: clock.now + 1_000)
            s.settle { drawn.values.last.map(FrameReport.place) == [0, 0, 100, 100] }
            s.turn()
            s.expect(told.values, [], "taken away: no dismissal")
            s.expect(drawn.values.last.map(FrameReport.place), [0, 0, 100, 100], "where its layout puts it again")
        }
    }

    /// A pan far enough a way the view listens for ends as a swipe that way; a short one, or one another way, is none.
    @MainActor
    static func swiped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPanFarEnoughItsWayIsASwipe", proves: [
            Covered(ViewContract.swiped, on: element), Covered(ViewContract.swipeDirections, on: element),
            Covered(ViewContract.swipeThreshold, on: element),
        ]) { s in
            let heard = Received<SwipeDirection>()
            s.start(clock: TestClock()) {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Write(ViewContract.swipeDirections, [.left, .right]), Write(ViewContract.swipeThreshold, 50),
                        Hear(ViewContract.swiped) { heard.values.append($0) },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.pan(by: Point(x: 20, y: 0)), on: view)
            try s.perform(.pan(by: Point(x: 0, y: -80)), on: view)
            s.turn()
            s.expect(heard.values, [], "short of the threshold, or a way it does not listen for")
            try s.perform(.pan(by: Point(x: -80, y: 0)), on: view)
            s.settle { !heard.values.isEmpty }
            s.expect(heard.values, [.left])
        }
    }

    /// Two fingers over a view are heard with their scale and where they are.
    @MainActor
    static func pinched(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPinchIsHeardWithItsScaleAndPlace", proves: [
            Covered(ViewContract.pinchUpdated, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start(clock: TestClock()) {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        HearFour(ViewContract.pinchUpdated) { _, scale, pivot, _ in
                            heard.values.append("\(scale) at \(pivot.x),\(pivot.y)")
                        },
                    ])
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.pinch(scale: 1.5, at: Point(x: 0.25, y: 0.75)), on: s.element("specimen"))
            s.settle { heard.values.contains("1.5 at 0.25,0.75") }
            s.expect(heard.values.contains("1.5 at 0.25,0.75"), true, "its scale and its place, \(heard.values)")
        }
    }

    /// Two fingers turning over a view are heard from where they began, and as they lift, as fast as they turned.
    @MainActor
    static func rotated(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).twoFingersTurningAreHeardFromTheirStart", proves: [
            Covered(ViewContract.rotationUpdated, on: element),
        ]) { s in
            let heard = Received<String>()
            let lifted = Received<Double>()
            s.start(clock: TestClock()) {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        HearThree(ViewContract.rotationUpdated) { phase, angle, velocity in
                            heard.values.append("\(phase) \(Int(angle.rounded()))")
                            if phase == .ended { lifted.values.append(velocity) }
                        },
                    ])
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.rotate(degrees: 30, at: Point(x: 0.5, y: 0.5)), on: s.element("specimen"))
            s.settle { heard.values.last?.hasPrefix("ended") == true }
            s.expect(heard.values.first, "began 0", "heard as they begin")
            s.expect(heard.values.contains("changed 30"), true, "turned as far as they went, \(heard.values)")
            s.expect(heard.values.last, "ended 30", "and as they lift, where they reached")
            s.expect(lifted.values.last.map { $0 > 0 }, true, "lifting as they turned, clockwise")
        }
    }

    /// The pointer coming over a view, moving, pressing, letting go and leaving is heard, where it is.
    @MainActor
    static func pointed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).thePointerIsHeardComingMovingPressingAndGoing", proves: [
            Covered(ViewContract.pointerMoved, on: element), Covered(ViewContract.pointerPressed, on: element),
            Covered(ViewContract.pointerReleased, on: element),
        ], needs: [
            Covered(HoverElementContract.pointerEntered, on: element), Covered(HoverElementContract.pointerExited, on: element),
        ], pointing(element))
    }

    /// The pointer coming over the view, pressing, letting go and leaving: what `pointed` and the hover's case on a
    /// view both run.
    @MainActor
    static func pointing(_ element: String) -> @MainActor (Session) throws -> Void {
        { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        HearDone(HoverElementContract.pointerEntered) { heard.values.append("entered") },
                        Hear(ViewContract.pointerMoved) { heard.values.append("moved \(Self.at($0))") },
                        Hear(ViewContract.pointerPressed) { heard.values.append("pressed \(Self.at($0))") },
                        Hear(ViewContract.pointerReleased) { heard.values.append("released \(Self.at($0))") },
                        HearDone(HoverElementContract.pointerExited) { heard.values.append("exited") },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.hover(at: Point(x: 10, y: 12)), on: view)
            try s.perform(.pressDown(at: Point(x: 10, y: 12)), on: view)
            try s.perform(.lift(at: Point(x: 10, y: 12)), on: view)
            try s.perform(.leave, on: view)
            s.settle { heard.values.last == "exited" }
            s.expect(heard.values, ["entered", "moved 10,12", "pressed 10,12", "released 10,12", "exited"])
        }
    }

    /// A view that can be dragged, dragged onto one that takes drops, carries its words there: its drag heard
    /// starting and ending, the one it landed on the words.
    @MainActor
    static func dragged(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aDragFromItCarriesItsWords", proves: [
            Covered(ViewContract.isDraggable, on: element), Covered(ViewContract.dragText, on: element),
            Covered(ViewContract.dragStarting, on: element), Covered(ViewContract.dragEnded, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.isDraggable, true), Write(ViewContract.dragText, "words"),
                        HearDone(ViewContract.dragStarting) { heard.values.append("starting") },
                        HearDone(ViewContract.dragEnded) { heard.values.append("completed") },
                    ])
                    Rectangle()
                        .fill(.red)
                        .width(80)
                        .height(40)
                        .setValue(ViewContract.allowsDrop, true)
                        .onEvent(ViewContract.dropped) { heard.values.append("drop \($0)") }.id("target")
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.dragAndDrop(onto: "target"), on: s.element("specimen"))
            s.settle { heard.values.last == "completed" }
            s.expect(heard.values, ["starting", "drop words", "completed"])
        }
    }

    /// A view that takes drops hears a drag come over it and go, and the words of one dropped on it.
    @MainActor
    static func droppedOn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aDropOnItIsHeardWithItsWords", proves: [
            Covered(ViewContract.allowsDrop, on: element), Covered(ViewContract.dropped, on: element),
            Covered(ViewContract.dragEntered, on: element), Covered(ViewContract.dragExited, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Rectangle()
                        .fill(.red)
                        .width(80)
                        .height(40)
                        .setValue(ViewContract.dragText, "words").id("source")
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.allowsDrop, true),
                        HearDone(ViewContract.dragEntered) { heard.values.append("over") },
                        HearDone(ViewContract.dragExited) { heard.values.append("left") },
                        Hear(ViewContract.dropped) { heard.values.append("drop \($0)") },
                    ], id: "crossed")
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.allowsDrop, true), Hear(ViewContract.dropped) { heard.values.append("drop \($0)") },
                    ], id: "target")
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.dragAndDrop(onto: "target", across: "crossed"), on: s.element("source"))
            s.settle { heard.values.contains { $0.hasPrefix("drop") } }
            s.expect(heard.values, ["over", "left", "drop words"], "the one crossed heard it come and go")
        }
    }

    /// A view that takes files hears those of its kinds the user drops on it from the system, by their names - a drop
    /// of none of its kinds heard by nobody.
    @MainActor
    static func filesDroppedOn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).filesDroppedOnItAreHeardByTheirKind", proves: [
            Covered(ViewContract.droppedFileTypes, on: element), Covered(ViewContract.filesDropped, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.droppedFileTypes, [FileType("Text", extensions: ["txt"])]),
                        Hear(ViewContract.filesDropped) { heard.values.append($0.map(\.name).joined(separator: " ")) },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.dropFiles(["photo.png"]), on: view)
            try s.perform(.dropFiles(["note.txt", "photo.png"]), on: view)
            s.settle { !heard.values.isEmpty }
            s.expect(heard.values, ["note.txt"], "the file of its kind, nothing of another")
        }
    }

    /// Where a pointer is, as a case says it: whole points, or nowhere.
    static func at(_ point: Point?) -> String {
        point.map { "\(Int($0.x)),\(Int($0.y))" } ?? "nowhere"
    }

    /// `element`'s specimen wearing `worn`, its frames heard by `frames`.
    @MainActor
    static func reporting(
        _ element: String, _ frames: Received<[Double]>, _ worn: [any Worn], id: String = "specimen"
    ) -> AnyView {
        Specimens.view(element, worn + [Hear(ViewContract.layoutFrameChanged) { numbers in frames.values.append(numbers) }], id: id)
    }
}

/// A stack two hundred points across moving its children over six tenths of a second, holding one view of forty at
/// its start - or, once `far`, at its end: a change that moves the view a hundred and sixty points. The view says
/// where its layout puts it to `placed`, and the rectangle around what is drawn of it to `drawn`.
private struct Carried: View {
    let far: Binding<Bool>
    let placed: Received<[Double]>
    let drawn: Received<[Double]>

    var body: some View {
        VStack {
            Rectangle()
                .fill(.red)
                .width(40)
                .height(40)
                .horizontalAlignment(far.wrappedValue ? .end : .start)
                .onEvent(ViewContract.layoutFrameChanged) { placed.values.append($0) }
                .onEvent(ViewContract.presentationFrameChanged) { drawn.values.append($0) }
                .id("specimen")
        }
        .width(200)
        .height(40)
        .horizontalAlignment(.start)
        .motion(.eased(.milliseconds(600), curve: .linear))
    }
}
