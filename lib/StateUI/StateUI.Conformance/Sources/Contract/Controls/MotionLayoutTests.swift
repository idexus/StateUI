// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `MotionLayoutContract` on a host: each view stands where the arithmetic puts it - one made with the layout sets out
/// from its shared partner onto that place - the arithmetic is handed the room
/// the layout was given and handed it again when it changes, measures its views as they stand by themselves and again
/// when one is sized anew, the layout takes no size from its views but the one it measures, the phase the
/// program sends travels there and is awaited - each axis of it on its own - a view under a press goes to the hand
/// and is dismissed let go far enough, and a layout mirrored right to left stands its views and hears the hand
/// turned about its middle. What a hand does to the number its interaction names is the View tier's.
@_spi(Host) public enum MotionLayoutTests: ConformanceFamily {
    public static let name = "MotionLayout"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("MotionLayout"),
            ConformanceCase("eachViewStandsWhereItsArithmeticPutsIt", proves: [
                Covered(MotionLayoutContract.self), Covered(MotionLayoutContract.layout),
            ]) { s in
                let (first, second) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        MotionLayout([0, 1], parameters: State(wrappedValue: 0.0).projectedValue) { index in
                            Rectangle()
                                .fill(index == 0 ? .red : .blue)
                                .onEvent(ViewContract.layoutFrameChanged) { (index == 0 ? first : second).values.append($0) }
                        } placements: { _, _ in
                            [Placement(Rect(x: 0, y: 0, width: 20, height: 10)), Placement(Rect(x: 30, y: 10, width: 20, height: 20))]
                        }
                        .width(60).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                // The second's corner from the first's: where the layout itself stands in the window is no matter.
                let apart = {
                    guard let one = first.values.last.map(FrameReport.inContent),
                          let two = second.values.last.map(FrameReport.inContent)
                    else { return [Double]() }
                    return [two[0] - one[0], two[1] - one[1]]
                }
                s.settle { apart() == [30, 10] }
                s.expect(first.values.last.map(FrameReport.size), [20, 10], "the first at the size its placement gives")
                s.expect(second.values.last.map(FrameReport.size), [20, 20], "the second at its own")
                s.expect(apart(), [30, 10], "and where the second's placement stands it from the first")
            },
            ConformanceCase("aViewMadeWithItSetsOutFromItsPartnerOntoItsPlace", proves: [
                Covered(MotionLayoutContract.self), Covered(MotionLayoutContract.layout),
            ], needs: [
                Covered(ViewContract.transitionID, on: RectangleContract.self),
                Covered(ViewContract.presentationFrameChanged, on: RectangleContract.self),
                Covered(ClickElementContract.clicked, on: ButtonContract.self),
            ]) { s in
                let clock = TestClock()
                let opened = State(wrappedValue: true)
                let drawn = Received<[Double]>()
                let way = Motion.eased(.milliseconds(400), curve: .linear)
                s.start(clock: clock) {
                    VStack {
                        Button("Back").onClicked { opened.wrappedValue = false }.id("back")
                        VStack {
                            if opened.wrappedValue {
                                Rectangle().fill(.red).transitionID(1).width(100).height(60).motion(way)
                            } else {
                                MotionLayout([1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { card in
                                    Rectangle()
                                        .fill(.blue)
                                        .transitionID(card)
                                        .motion(way)
                                        .onEvent(ViewContract.presentationFrameChanged) {
                                            if card == 1 { drawn.values.append($0) }
                                        }
                                } placements: { _, _ in
                                    [Placement(Rect(x: 10, y: 10, width: 40, height: 40)),
                                     Placement(Rect(x: 60, y: 10, width: 40, height: 40))]
                                }
                                .width(120).height(80)
                            }
                        }
                        .horizontalAlignment(.start)
                        .verticalAlignment(.start)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.frames(of: clock, until: 200)

                // The layout is laid out before the display's frame asks its program: its first pass asks it.
                try s.perform(.activate, on: s.element("back"))
                s.settle { !drawn.values.isEmpty }
                let first = drawn.values.first.map(FrameReport.size) ?? []
                s.expect(first.map { $0.rounded() }, [100, 60], "it sets out as large as its partner was drawn")

                s.frames(of: clock, until: 1_400)
                s.settle { drawn.values.last.map(FrameReport.size) == [40, 40] }
                s.expect(drawn.values.last.map(FrameReport.size), [40, 40], "and lands on the place its arithmetic gives it")
            },
            ConformanceCase("itsArithmeticIsHandedItsRoomAgainWhenItChanges", proves: [
                Covered(MotionLayoutContract.self), Covered(MotionLayoutContract.layout),
            ]) { s in
                let rooms = Received<Rect>()
                let width = State(wrappedValue: 60.0)
                s.start {
                    VStack {
                        MotionLayout([0], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
                            Rectangle()
                                .fill(.red)
                        } placements: { context, _ in
                            rooms.values.append(context.bounds)
                            return [Placement(Rect(x: 0, y: 0, width: 10, height: 10))]
                        }
                        .width(width.projectedValue).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                s.settle { rooms.values.last == Rect(x: 0, y: 0, width: 60, height: 40) }
                s.expect(rooms.values.last, Rect(x: 0, y: 0, width: 60, height: 40), "the room it was given, from its own top left")

                width.wrappedValue = 90
                s.settle { rooms.values.last == Rect(x: 0, y: 0, width: 90, height: 40) }
                s.expect(rooms.values.last, Rect(x: 0, y: 0, width: 90, height: 40), "and the new room it was given")
            },
            ConformanceCase("itHasNoSizeOfItsOwn", proves: [Covered(MotionLayoutContract.self)]) { s in
                let (above, below) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        Rectangle()
                            .fill(.blue)
                            .width(20)
                            .height(10)
                            .onEvent(ViewContract.layoutFrameChanged) { above.values.append($0) }
                        MotionLayout([0], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
                            Rectangle()
                                .fill(.red)
                                .width(40)
                                .height(40)
                        } placements: { context, _ in
                            [Placement(context.bounds)]
                        }
                        Rectangle()
                            .fill(.green)
                            .width(20)
                            .height(10)
                            .onEvent(ViewContract.layoutFrameChanged) { below.values.append($0) }
                    }
                    .spacing(0)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                // How far below the first view the last stands: the first's height alone where the layout between
                // them takes none.
                let apart = {
                    guard let one = above.values.last.map(FrameReport.inContent),
                          let two = below.values.last.map(FrameReport.inContent)
                    else { return -1.0 }
                    return two[1] - one[1]
                }
                s.settle { apart() == 10 }
                s.expect(apart(), 10, "the view below right under the one above, whatever the layout's view needs")
            },
            ConformanceCase("itsArithmeticMeasuresItsViews", proves: [
                Covered(MotionLayoutContract.self), Covered(MotionLayoutContract.layout),
            ]) { s in
                let (first, second) = (Received<[Double]>(), Received<[Double]>())
                let width = State(wrappedValue: 40.0)
                s.start {
                    VStack {
                        MotionLayout([0, 1], parameters: State(wrappedValue: 0.0).projectedValue) { index in
                            if index == 0 {
                                Rectangle()
                                    .fill(.red)
                                    .width(width.projectedValue)
                                    .height(20)
                                    .onEvent(ViewContract.layoutFrameChanged) { first.values.append($0) }
                            } else {
                                Rectangle()
                                    .fill(.blue)
                                    .width(24)
                                    .height(30)
                                    .onEvent(ViewContract.layoutFrameChanged) { second.values.append($0) }
                            }
                        } placements: { context, _ in
                            // Side by side, six points apart, each at the size it measures.
                            var across = 0.0
                            return context.subviews.map { view in
                                let size = view.sizeThatFits()
                                defer { across += size.width + 6 }
                                return Placement(Rect(x: across, y: 0, width: size.width, height: size.height))
                            }
                        }
                        .width(200).height(60)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                let apart = {
                    guard let one = first.values.last.map(FrameReport.inContent),
                          let two = second.values.last.map(FrameReport.inContent)
                    else { return [Double]() }
                    return [two[0] - one[0], two[1] - one[1]]
                }
                s.settle { apart() == [46, 0] && first.values.last.map(FrameReport.size) == [40, 20] }
                s.expect(first.values.last.map(FrameReport.size), [40, 20], "the first at the size it measures")
                s.expect(second.values.last.map(FrameReport.size), [24, 30], "the second at its own")
                s.expect(apart(), [46, 0], "the second after the first's width")

                // A view sized anew is measured again, and the layout worked out by it - on every frame of the
                // way to its new size, so the case waits for the way's end.
                width.wrappedValue = 70
                s.settle { apart() == [76, 0] && first.values.last.map(FrameReport.size) == [70, 20] }
                s.expect(first.values.last.map(FrameReport.size), [70, 20], "the first at its new size")
                s.expect(apart(), [76, 0], "and the second after it")
            },
            ConformanceCase("aViewMeasuresAsItStandsByItself", proves: [
                Covered(MotionLayoutContract.self), Covered(MotionLayoutContract.layout),
            ], needs: [Covered(TextContract.self)]) { s in
                let (alone, measured) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        Text("Measured words")
                            .horizontalAlignment(.start)
                            .onEvent(ViewContract.layoutFrameChanged) { alone.values.append($0) }
                        MotionLayout([0], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
                            Text("Measured words")
                                .onEvent(ViewContract.layoutFrameChanged) { measured.values.append($0) }
                        } placements: { context, _ in
                            context.subviews.map { view in
                                let size = view.sizeThatFits()
                                return Placement(Rect(x: 0, y: 0, width: size.width, height: size.height))
                            }
                        }
                        .width(300).height(60)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                // The same words: in the layout at the size they measure, beside it at the size they take.
                let alike = {
                    guard let one = alone.values.last.map(FrameReport.size), one.count == 2, one[0] > 0,
                          let two = measured.values.last.map(FrameReport.size), two.count == 2
                    else { return false }
                    return abs(one[0] - two[0]) <= 1 && abs(one[1] - two[1]) <= 1
                }
                s.settle { alike() }
                s.expect(
                    measured.values.last.map(FrameReport.size).map { $0.map { $0.rounded() } },
                    alone.values.last.map(FrameReport.size).map { $0.map { $0.rounded() } },
                    "words measured for a layout are as large as the same words standing alone")
            },
            ConformanceCase("itsOwnSizeIsTheOneItMeasures", proves: [
                Covered(MotionLayoutContract.self), Covered(MotionLayoutContract.layout),
            ]) { s in
                let (above, below) = (Received<[Double]>(), Received<[Double]>())
                let height = State(wrappedValue: 30.0)
                s.start {
                    VStack {
                        Rectangle()
                            .fill(.blue)
                            .width(20)
                            .height(10)
                            .onEvent(ViewContract.layoutFrameChanged) { above.values.append($0) }
                        MotionLayout([0], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
                            Rectangle()
                                .fill(.red)
                                .width(40)
                                .height(height.projectedValue)
                        } placements: { context, _ in
                            context.subviews.map { view in
                                let size = view.sizeThatFits()
                                return Placement(Rect(x: 0, y: 0, width: size.width, height: size.height))
                            }
                        }
                        // As large as its tallest view.
                        .measure { context, _ in
                            let sizes = context.subviews.map { $0.sizeThatFits() }
                            return LayoutSize(
                                width: sizes.map(\.width).max() ?? 0, height: sizes.map(\.height).max() ?? 0)
                        }
                        Rectangle()
                            .fill(.green)
                            .width(20)
                            .height(10)
                            .onEvent(ViewContract.layoutFrameChanged) { below.values.append($0) }
                    }
                    .spacing(0)
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }

                // How far below the first view the last stands: the first's height and the layout's own.
                let apart = {
                    guard let one = above.values.last.map(FrameReport.inContent),
                          let two = below.values.last.map(FrameReport.inContent)
                    else { return -1.0 }
                    return two[1] - one[1]
                }
                s.settle { apart() == 40 }
                s.expect(apart(), 40, "the view below under a layout as tall as its view measures")

                // Its view grown, the layout says another size and is measured again.
                height.wrappedValue = 50
                s.settle { apart() == 60 }
                s.expect(apart(), 60, "and under the taller layout once its view grew")
            },
            ConformanceCase("aRowTurnedColumnKeepsItsFieldsAndTheKeyboard", proves: [
                Covered(MotionLayoutContract.self), Covered(MotionLayoutContract.layout),
            ], needs: [
                Covered(FocusElementContract.focus, on: "TextField"), Covered(TextElementContract.text, on: "TextField"),
            ]) { s in
                let (name, city) = (State(wrappedValue: ""), State(wrappedValue: ""))
                let width = State(wrappedValue: 400.0)
                let rows = Received<Int>()
                s.start {
                    VStack {
                        MotionLayout([0, 1], parameters: State(wrappedValue: 0.0).projectedValue) { index in
                            TextField(index == 0 ? name.projectedValue : city.projectedValue)
                                .width(150)
                                .id(index == 0 ? "name" : "city")
                        } placements: { context, _ in
                            // Side by side while the fields' own widths fit the room, else one under the other.
                            let sizes = context.subviews.map { $0.sizeThatFits() }
                            let stacked = sizes.reduce(10) { $0 + $1.width } > context.bounds.width
                            rows.values.append(stacked ? 2 : 1)
                            var (across, down) = (0.0, 0.0)
                            return sizes.map { size in
                                defer { if stacked { down += size.height + 10 } else { across += size.width + 10 } }
                                return Placement(Rect(x: across, y: down, width: size.width, height: size.height))
                            }
                        }
                        .width(width.projectedValue).height(140)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                let field = try s.element("name")
                let mounted = field.mount

                try s.perform(.focus, on: field)
                try s.settle { try s.focused(field) }
                try s.perform(.type("Ada"), on: field)
                s.settle { name.wrappedValue == "Ada" && rows.values.last == 1 }
                s.expect(rows.values.last, 1, "side by side while the room holds both")

                width.wrappedValue = 200
                s.settle { rows.values.last == 2 }
                s.expect(rows.values.last, 2, "one under the other in the narrower room")
                let after = try s.element("name")
                s.expect(after.mount, mounted, "the same field, made once")
                s.expect(try s.focused(after), true, "which holds the keyboard still")
                s.expect(try s.held(TextElementContract.text, on: after), "Ada", "and the words typed in it")
            },
            ConformanceCase("mirroredRightToLeftItsViewsStandTurnedAboutItsMiddle", proves: [
                Covered(MotionLayoutContract.mirrorsRightToLeft),
            ], needs: [Covered(VisualElementContract.layoutDirection, on: "VStack")]) { s in
                let (first, second) = (Received<[Double]>(), Received<[Double]>())
                s.start {
                    VStack {
                        MotionLayout([0, 1], parameters: State(wrappedValue: 0.0).projectedValue) { index in
                            Rectangle()
                                .fill(index == 0 ? .red : .blue)
                                .onEvent(ViewContract.layoutFrameChanged) { (index == 0 ? first : second).values.append($0) }
                        } placements: { _, _ in
                            [Placement(Rect(x: 0, y: 0, width: 20, height: 10)), Placement(Rect(x: 30, y: 10, width: 20, height: 20))]
                        }
                        .mirrorsRightToLeft(true)
                        .width(60).height(40)
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                    .layoutDirection(.rightToLeft)
                }

                // Written 30 to the right of the first, the second stands 30 to its left: each turned about the middle.
                let apart = {
                    guard let one = first.values.last.map(FrameReport.inContent),
                          let two = second.values.last.map(FrameReport.inContent)
                    else { return [Double]() }
                    return [two[0] - one[0], two[1] - one[1]]
                }
                s.settle { apart() == [-30, 10] }
                s.expect(second.values.last.map(FrameReport.size), [20, 20], "at the size its placement gives")
                s.expect(apart(), [-30, 10], "the second the mirror of where it is written from the first")
            },
            ConformanceCase("thePhaseTravelsWhereTheProgramSendsIt", proves: [
                Covered(MotionLayoutContract.parameters),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let clock = TestClock()
                let phase = State(wrappedValue: 0.0, motion: .eased(.milliseconds(400), curve: .linear))
                let (handed, arrived) = (Received<Double>(), Received<MotionResult>())
                s.start(clock: clock) {
                    VStack {
                        MotionLayout([0], parameters: phase.projectedValue) { _ in
                            Rectangle()
                                .fill(.red)
                        } placements: { _, phase in
                            handed.values.append(phase)
                            return [Placement(Rect(x: phase * 10, y: 0, width: 20, height: 20))]
                        }
                        .width(100).height(40)
                        Button("Go").onClicked(policy: .ignoreWhileRunning) {
                            arrived.values.append(try await phase.projectedValue.journey.move(to: 4).result())
                        }
                        .id("go")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { handed.values.last == 0 }

                // The handler runs as the host runs a run's first steps; the clock waits for it.
                try s.perform(.activate, on: s.element("go"))
                s.settle { phase.wrappedValue == 4 }
                s.frames(of: clock, until: 200)
                let between = handed.values.last ?? 0
                s.expect(between > 0 && between < 4, true, "on its way half its time in, never at the destination at once")

                s.frames(of: clock, until: 1_000)
                s.settle { arrived.values == [.reached(.animated)] }
                s.expect(handed.values.last, 4, "where the program sent it")
                s.expect(arrived.values, [.reached(.animated)], "and a move of it awaited until it arrived")
            },
            ConformanceCase("aRunSentOnTellsItsRestOnceWhereItStands", proves: [
                Covered(MotionLayoutContract.settled),
            ], needs: [
                Covered(MotionLayoutContract.parameters),
                Covered(ClickElementContract.clicked, on: ButtonContract.self),
            ]) { s in
                let clock = TestClock()
                let phase = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200), curve: .linear))
                let rested = Received<Double>()
                s.start(clock: clock) {
                    VStack {
                        MotionLayout([0], parameters: phase.projectedValue) { _ in
                            Rectangle()
                                .fill(.red)
                        } placements: { _, phase in
                            [Placement(Rect(x: phase * 10, y: 0, width: 20, height: 20))]
                        }
                        .onSettled { rested.values.append($0) }
                        .width(100).height(40)
                        Button("Go").onClicked { phase.wrappedValue = 4 }
                            .id("go")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.frames(of: clock, until: 64)
                s.turn()
                s.expect(rested.values, [], "laid out at rest, it tells nothing")

                try s.perform(.activate, on: s.element("go"))
                s.settle { phase.wrappedValue == 4 }
                s.frames(of: clock, until: clock.now + 96)
                s.turn()
                s.expect(rested.values, [], "on its way, no rest")

                s.frames(of: clock, until: clock.now + 600)
                s.settle { rested.values == [4] }
                s.frames(of: clock, until: clock.now + 200)
                s.turn()
                s.expect(rested.values, [4], "told once, where its parameters rest")
            },
            ConformanceCase("eachAxisOfThePhaseTravelsOnItsOwn", proves: [
                Covered(MotionLayoutContract.parameters),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let clock = TestClock()
                let phase = State(wrappedValue: Orbit(), motion: .eased(.milliseconds(400), curve: .linear))
                let (handed, arrived) = (Received<Orbit>(), Received<MotionResult>())
                s.start(clock: clock) {
                    VStack {
                        MotionLayout([0], parameters: phase.projectedValue) { _ in
                            Rectangle()
                                .fill(.red)
                        } placements: { _, phase in
                            handed.values.append(phase)
                            return [Placement(Rect(x: phase.turn * 10, y: 0, width: 20 * phase.zoom, height: 20))]
                        }
                        .width(100).height(40)
                        Button("Turn").onClicked(policy: .ignoreWhileRunning) {
                            arrived.values.append(try await phase.projectedValue.journey.move(to: Orbit(turn: 4)).result())
                        }
                        .id("turn")
                        Button("Zoom").onClicked { phase.wrappedValue.zoom = 2 }
                            .id("zoom")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { handed.values.last == Orbit() }

                try s.perform(.activate, on: s.element("turn"))
                s.settle { phase.wrappedValue.turn == 4 }
                s.frames(of: clock, until: 200)
                try s.perform(.activate, on: s.element("zoom"))
                s.settle { phase.wrappedValue.zoom == 2 }

                // The turn's 400 ms end, the zoom sent halfway through it still on its way.
                s.frames(of: clock, until: 432)
                s.settle { arrived.values == [.reached(.animated)] }
                s.expect(handed.values.last?.turn, 4, "the turn arrived when it was due, the zoom sent meanwhile")
                s.expect(handed.values.last.map { $0.zoom > 1 && $0.zoom < 2 }, true, "the zoom on its own way")
                s.expect(arrived.values, [.reached(.animated)], "and the turn's move awaited to its end")

                s.frames(of: clock, until: 1_000)
                s.expect(handed.values.last, Orbit(turn: 4, zoom: 2), "both where they were sent")
            },
            ConformanceCase("mirroredRightToLeftTheHandMovesTheRunTheOtherWay", proves: [
                Covered(MotionLayoutContract.mirrorsRightToLeft),
            ], needs: [Covered(ViewContract.interaction, on: MotionLayoutContract.self), Covered(VisualElementContract.layoutDirection, on: "VStack")]) { s in
                let (clock, phase) = (TestClock(), State(wrappedValue: 0.0))
                let layout = try HandLayouts.hand(s, clock: clock, phase: phase, mirrored: true)

                // 140 points to the right is 1.4 targets on in the mirror: let go still, it rests on the nearest.
                try s.perform(.sweep(by: Point(x: 140, y: 0), speed: .zero), on: layout)
                s.frames(of: clock, until: 1_600)

                s.expect(phase.wrappedValue, 1, "on, the hand going the mirror's way")
            },
            ConformanceCase("anAxisOfKeyframesAloneLeavesTheHandAlone", proves: [
                Covered(MotionLayoutContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let arrangement = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200), curve: .linear))
                let (clock, handed) = (TestClock(), Received<Double>())
                s.start(clock: clock) {
                    VStack {
                        MotionLayout([0], parameters: arrangement.projectedValue) { _ in
                            Rectangle()
                                .fill(.red)
                        } placements: { _, at in
                            handed.values.append(at)
                            return [Placement(Rect(x: at * 60, y: 0, width: 20, height: 20))]
                        }
                        .axis(range: 0...1, keyframes: .every(1))
                        .width(100).height(40)
                        Button("Go").onClicked { arrangement.wrappedValue = 1 }
                            .id("go")
                    }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
                }
                s.settle { handed.values.last == 0 }
                let layout = try s.element(ofType: .motionLayout)

                // Declared with keyframes and no input: the hand passes it by, the program moves it.
                try s.perform(.sweep(by: Point(x: -140, y: 0), speed: Point(x: -600, y: 0)), on: layout)
                s.frames(of: clock, until: 1_600)
                s.expect(arrangement.wrappedValue, 0, "no hand moves an axis of keyframes alone")

                try s.perform(.activate, on: s.element("go"))
                s.frames(of: clock, until: 3_200)
                s.settle { handed.values.last == 1 }
                s.expect(handed.values.last, 1, "the program moves it to its keyframe")
            },
            ConformanceCase("aLongPressTakesTheViewUnderItToTheHand", proves: [
                Covered(MotionLayoutContract.itemDragUpdated),
            ], needs: [Covered(ViewContract.interaction, on: RectangleContract.self)]) { s in
                let (clock, phase, told) = (TestClock(), State(wrappedValue: 0.0), Received<String>())
                let view = try itemLayout(s, clock: clock, phase: phase, drag: .drag(.both, begins: .longPress), told: told)

                // The middle view stands from 30 to 50 across and 10 to 30 down: a press at its middle held past
                // a long press is its, and the layout is told where the hand is in its own room.
                try s.perform(.pressDown(at: Point(x: 10, y: 10)), on: view)
                s.frames(of: clock, until: clock.now + 600)
                try s.perform(.drag(to: Point(x: 40, y: 20)), on: view)
                s.frames(of: clock, until: clock.now + 48)
                try s.perform(.lift(at: Point(x: 40, y: 20)), on: view)
                s.frames(of: clock, until: clock.now + 600)

                s.expect(told.values.first, "1 at 40,20", "the view under the press, where it went down")
                s.expect(told.values.last, "1 at 70,30", "and where the hand took it")
                s.expect(phase.wrappedValue, 0, "the run stands")
            },
            ConformanceCase("aFirstMoveAcrossTakesTheViewUnderThePress", proves: [
                Covered(MotionLayoutContract.itemDragUpdated),
            ], needs: [Covered(ViewContract.interaction, on: RectangleContract.self)]) { s in
                let (clock, phase, told) = (TestClock(), State(wrappedValue: 0.0), Received<String>())
                let view = try itemLayout(
                    s, clock: clock, phase: phase, drag: .drag(.vertical, begins: .directional), told: told)

                try s.perform(.pressDown(at: Point(x: 10, y: 5)), on: view)
                try s.perform(.drag(to: Point(x: 12, y: 25)), on: view)
                s.frames(of: clock, until: clock.now + 48)
                try s.perform(.lift(at: Point(x: 12, y: 25)), on: view)
                s.frames(of: clock, until: clock.now + 600)

                s.expect(told.values.first, "1 at 40,15", "the view under the press")
                s.expect(told.values.last, "1 at 40,35", "moved down with the hand, and no way across: its drag's way")
                s.expect(phase.wrappedValue, 0, "the run stands")
            },
            ConformanceCase("aViewLetGoFarEnoughIsDismissed", proves: [
                Covered(MotionLayoutContract.itemDismissed),
            ], needs: [
                Covered(ViewContract.interaction, on: RectangleContract.self),
                Covered(MotionLayoutContract.itemDragUpdated),
            ]) { s in
                let (clock, phase, told) = (TestClock(), State(wrappedValue: 0.0), Received<String>())
                let view = try itemLayout(
                    s, clock: clock, phase: phase,
                    drag: .drag(.vertical, begins: .directional).dismissal(directions: .down, threshold: 10),
                    told: told, dismissing: true)

                try s.perform(.pressDown(at: Point(x: 10, y: 5)), on: view)
                try s.perform(.drag(to: Point(x: 10, y: 28)), on: view)
                s.frames(of: clock, until: clock.now + 48)
                try s.perform(.lift(at: Point(x: 10, y: 28)), on: view)
                s.frames(of: clock, until: clock.now + 1_000)
                s.settle { told.values.last == "1 dismissed" }

                s.expect(told.values.last, "1 dismissed", "flown out of the room, its item told")
            },
        ]
    }
}

/// A layout of three views a hand moves across, each taken by itself as its own `drag` says - told to `told` with
/// where the hand is, and one thrown away told where `dismissing` - its run on `clock`: the
/// middle view's element, once the room is told.
@MainActor
private func itemLayout(
    _ s: Session, clock: TestClock, phase: State<Double>, drag: Interaction, told: Received<String>,
    dismissing: Bool = false
) throws -> MountedElement {
    // The parameters travel under their state's own motion.
    try? phase.projectedValue.journey.setMotion(.eased(.milliseconds(200), curve: .linear))
    s.start(clock: clock) {
        VStack {
            let layout = MotionLayout([0, 1, 2], parameters: phase.projectedValue) { index in
                Rectangle()
                    .fill(.red)
                    .interaction(drag)
                    .id("view\(index)")
            } placements: { _, at in
                (0..<3).map { Placement(Rect(x: (Double($0) - at) * 30, y: 10, width: 20, height: 20)) }
            }
            .interaction(
                .value(phase.projectedValue, input: .translation(.horizontal, unit: .points(100))).reversed(true).range(0...2).snaps(.every(1))
                    .release(.projected(.eased(.milliseconds(400)))))
            .onItemDragged { told.values.append("\($0.id) at \(Int($0.at.x)),\(Int($0.at.y))") }
            if dismissing {
                layout.onItemDismissed { told.values.append("\($0) dismissed") }
                    .width(100).height(40)
            } else {
                layout.width(100).height(40)
            }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
    s.frames(of: clock, until: 64)
    return try s.element("view1")
}

/// A phase of two axes: how far a run is turned, and how large it stands.
private struct Orbit: LayoutParameters {
    var turn = 0.0
    var zoom = 1.0

    static var axes: [WritableKeyPath<Orbit, Double>] { [\.turn, \.zoom] }
}
