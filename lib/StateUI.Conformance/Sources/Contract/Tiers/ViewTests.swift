// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ViewContract` on a host: where a view stands in its parent - its margin, its alignment, its area in a layered
/// stack, its cell in a grid - as the frame it reports says, StateUI's arithmetic alike on every host; and what it
/// hears of the user's hand - taps counted, a pan carrying its states and ending as a swipe, a pinch, the pointer
/// coming, moving, pressing and going, a drag and a drop; each case made for every element wearing the tier.
@_spi(Host) public enum ViewTests: ConformanceFamily {
    public static let name = "View"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ViewContract.self).flatMap { element in
            [
                margined(element), aligned(element), inArea(element), inCell(element), acrossCells(element),
                tapped(element), panned(element), pannedDown(element), swiped(element), pinched(element), pointed(element),
                dragged(element), droppedOn(element),
            ]
        }
    }

    /// A view stands its margin in from its parent's corner.
    static func margined(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsInsideItsMargin", covers: [
            Covered(ViewContract.margin, on: element), Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    reporting(element, frames, [
                        Write(VisualElementContract.width, 120), Write(VisualElementContract.height, 40),
                        Write(ViewContract.margin, Insets(10, 6, 0, 0)),
                    ])
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(FrameReport.place) == [10, 6, 120, 40] }
            s.expect(frames.values.last.map(FrameReport.place), [10, 6, 120, 40], "x, y, width, height in its parent")
        }
    }

    /// A view stands where its alignment puts it in the room its parent gives it.
    static func aligned(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsWhereItsAlignmentPutsIt", covers: [
            Covered(ViewContract.horizontalAlignment, on: element), Covered(ViewContract.verticalAlignment, on: element),
            Covered(ViewContract.frameChanged, on: element),
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

    /// A view in a layered stack stands in its area: in points, then in shares of the room as the tree changes it.
    static func inArea(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsInItsArea", covers: [
            Covered(ViewContract.area, on: element), Covered(ViewContract.frameChanged, on: element),
            Covered(ButtonContract.clicked),
        ]) { s in
            let shared = State(wrappedValue: false)
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    ZStack {
                        reporting(element, frames, [
                            Write(ViewContract.area, shared.wrappedValue
                                  ? Area.proportional(0.5, 0.5, 0.5, 0.5) : Area.absolute(10, 20, 30, 40)),
                        ])
                    }
                    .width(200).height(200)
                    Button("Share").onClicked { shared.wrappedValue = true }.id("change")
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }

            s.settle { frames.values.last.map(FrameReport.place) == [10, 20, 30, 40] }
            s.expect(frames.values.last.map(FrameReport.place), [10, 20, 30, 40], "in points")
            try s.perform(.activate, on: s.element("change"))
            s.settle { frames.values.last.map(FrameReport.place) == [100, 100, 100, 100] }
            s.expect(frames.values.last.map(FrameReport.place), [100, 100, 100, 100], "its room's lower right quarter")
        }
    }

    /// A view in a grid stands in the cell its column and row name.
    static func inCell(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsInItsCell", covers: [
            Covered(ViewContract.gridColumn, on: element), Covered(ViewContract.gridRow, on: element),
            Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    Grid {
                        reporting(element, frames, [Write(ViewContract.gridColumn, 1), Write(ViewContract.gridRow, 1)])
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

    /// A view in a grid spanning columns and rows stands across them.
    static func acrossCells(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsAcrossTheCellsItSpans", covers: [
            Covered(ViewContract.gridColumnSpan, on: element), Covered(ViewContract.gridRowSpan, on: element),
            Covered(ViewContract.frameChanged, on: element),
        ]) { s in
            let frames = Received<[Double]>()
            s.start {
                VStack {
                    Grid {
                        reporting(element, frames, [Write(ViewContract.gridColumnSpan, 2), Write(ViewContract.gridRowSpan, 2)])
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
    static func tapped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aRunOfTapsIsHeardAtItsCount", covers: [
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

    /// A press dragged across a view is heard as it starts, runs and ends, carrying the state its pan across moves.
    static func panned(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPanIsHeardAndCarriesItsStateAcross", covers: [
            Covered(ViewContract.panUpdated, on: element), Covered(ViewContract.panTouchCount, on: element),
            Covered(ViewContract.panXChannel, on: element),
        ]) { s in
            let x = State(wrappedValue: 10.0)
            let heard = Received<String>()
            s.start {
                VStack {
                    Opened.pannedAcross(Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Write(ViewContract.panTouchCount, 1),
                        HearThree(ViewContract.panUpdated) { phase, totalX, totalY in
                            heard.values.append("\(phase) \(Int(totalX)) \(Int(totalY))")
                        },
                    ]), carrying: x.projectedValue)
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.pan(by: Point(-60, 20)), on: s.element("specimen"))
            s.settle { heard.values.last?.hasPrefix("completed") == true }
            s.expect(heard.values.first?.hasPrefix("started"), true, "heard as it starts")
            s.expect(heard.values.contains("running -60 20"), true, "running, with how far it went")
            s.expect(heard.values.last?.hasPrefix("completed"), true, "and as it ends")
            s.expect(x.wrappedValue, -50, "the state carried as far as the hand went across")
        }
    }

    /// A press dragged down a view carries the state its pan down moves.
    static func pannedDown(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPanCarriesItsStateDown", covers: [Covered(ViewContract.panYChannel, on: element)]) { s in
            let y = State(wrappedValue: 5.0)
            s.start {
                VStack {
                    Opened.pannedDown(Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                    ]), carrying: y.projectedValue)
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.pan(by: Point(0, 20)), on: s.element("specimen"))
            s.settle { y.wrappedValue == 25 }
            s.expect(y.wrappedValue, 25, "the state carried as far as the hand went down")
        }
    }

    /// A pan far enough a way the view listens for ends as a swipe that way; a short one, or one another way, is none.
    static func swiped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPanFarEnoughItsWayIsASwipe", covers: [
            Covered(ViewContract.swiped, on: element), Covered(ViewContract.swipeDirection, on: element),
            Covered(ViewContract.swipeThreshold, on: element),
        ]) { s in
            let heard = Received<SwipeDirection>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        Write(ViewContract.swipeDirection, [.left, .right]), Write(ViewContract.swipeThreshold, 50),
                        Hear(ViewContract.swiped) { heard.values.append($0) },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.pan(by: Point(20, 0)), on: view)
            try s.perform(.pan(by: Point(0, -80)), on: view)
            s.turn()
            s.expect(heard.values, [], "short of the threshold, or a way it does not listen for")
            try s.perform(.pan(by: Point(-80, 0)), on: view)
            s.settle { !heard.values.isEmpty }
            s.expect(heard.values, [.left])
        }
    }

    /// Two fingers over a view are heard with their scale and where they are.
    static func pinched(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPinchIsHeardWithItsScaleAndPlace", covers: [
            Covered(ViewContract.pinchUpdated, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        HearThree(ViewContract.pinchUpdated) { _, scale, origin in
                            heard.values.append("\(scale) at \(origin.x),\(origin.y)")
                        },
                    ])
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.pinch(scale: 1.5, at: Point(0.25, 0.75)), on: s.element("specimen"))
            s.settle { heard.values.contains("1.5 at 0.25,0.75") }
            s.expect(heard.values.contains("1.5 at 0.25,0.75"), true, "its scale and its place, \(heard.values)")
        }
    }

    /// The pointer coming over a view, moving, pressing, letting go and leaving is heard, where it is.
    static func pointed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).thePointerIsHeardComingMovingPressingAndGoing", covers: [
            Covered(ViewContract.pointerEntered, on: element), Covered(ViewContract.pointerMoved, on: element),
            Covered(ViewContract.pointerPressed, on: element), Covered(ViewContract.pointerReleased, on: element),
            Covered(ViewContract.pointerExited, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 100), Write(VisualElementContract.height, 100),
                        HearDone(ViewContract.pointerEntered) { heard.values.append("entered") },
                        Hear(ViewContract.pointerMoved) { heard.values.append("moved \(Self.at($0))") },
                        Hear(ViewContract.pointerPressed) { heard.values.append("pressed \(Self.at($0))") },
                        Hear(ViewContract.pointerReleased) { heard.values.append("released \(Self.at($0))") },
                        HearDone(ViewContract.pointerExited) { heard.values.append("exited") },
                    ])
                }
                .horizontalAlignment(.start)
            }
            let view = try s.element("specimen")

            try s.perform(.hover(at: Point(10, 12)), on: view)
            try s.perform(.pressDown(at: Point(10, 12)), on: view)
            try s.perform(.lift(at: Point(10, 12)), on: view)
            try s.perform(.leave, on: view)
            s.settle { heard.values.last == "exited" }
            s.expect(heard.values, ["entered", "moved 10,12", "pressed 10,12", "released 10,12", "exited"])
        }
    }

    /// A view that can be dragged, dragged across one that takes drops and onto another, carries its words there:
    /// its drag heard starting and ending, the one it crossed hearing it come and go, the one it landed on the words.
    static func dragged(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aDragFromItCarriesItsWords", covers: [
            Covered(ViewContract.canDrag, on: element), Covered(ViewContract.dragText, on: element),
            Covered(ViewContract.dragStarting, on: element), Covered(ViewContract.dropCompleted, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.canDrag, true), Write(ViewContract.dragText, "words"),
                        HearDone(ViewContract.dragStarting) { heard.values.append("starting") },
                        HearDone(ViewContract.dropCompleted) { heard.values.append("completed") },
                    ])
                    ColorBox(.red).width(80).height(40).setValue(ViewContract.allowDrop, true)
                        .onEvent(ViewContract.drop) { heard.values.append("drop \($0)") }.id("target")
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.dragAndDrop(onto: "target"), on: s.element("specimen"))
            s.settle { heard.values.last == "completed" }
            s.expect(heard.values, ["starting", "drop words", "completed"])
        }
    }

    /// A view that takes drops hears a drag come over it and go, and the words of one dropped on it.
    static func droppedOn(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aDropOnItIsHeardWithItsWords", covers: [
            Covered(ViewContract.allowDrop, on: element), Covered(ViewContract.drop, on: element),
            Covered(ViewContract.dragOver, on: element), Covered(ViewContract.dragLeave, on: element),
        ]) { s in
            let heard = Received<String>()
            s.start {
                VStack {
                    ColorBox(.red).width(80).height(40).setValue(ViewContract.canDrag, true)
                        .setValue(ViewContract.dragText, "words").id("source")
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.allowDrop, true),
                        HearDone(ViewContract.dragOver) { heard.values.append("over") },
                        HearDone(ViewContract.dragLeave) { heard.values.append("left") },
                        Hear(ViewContract.drop) { heard.values.append("drop \($0)") },
                    ], id: "crossed")
                    Specimens.view(element, [
                        Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                        Write(ViewContract.allowDrop, true), Hear(ViewContract.drop) { heard.values.append("drop \($0)") },
                    ], id: "target")
                }
                .horizontalAlignment(.start)
            }

            try s.perform(.dragAndDrop(onto: "target", across: "crossed"), on: s.element("source"))
            s.settle { heard.values.contains { $0.hasPrefix("drop") } }
            s.expect(heard.values, ["over", "left", "drop words"], "the one crossed heard it come and go")
        }
    }

    /// Where a pointer is, as a case says it: whole points, or nowhere.
    static func at(_ point: Point?) -> String {
        point.map { "\(Int($0.x)),\(Int($0.y))" } ?? "nowhere"
    }

    /// `element`'s specimen wearing `worn`, its frames heard by `frames`.
    static func reporting(
        _ element: String, _ frames: Received<[Double]>, _ worn: [any Worn], id: String = "specimen"
    ) -> any View {
        Specimens.view(element, worn + [Hear(ViewContract.frameChanged) { numbers in frames.values.append(numbers) }], id: id)
    }
}
