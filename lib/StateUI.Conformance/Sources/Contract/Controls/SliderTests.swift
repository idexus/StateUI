// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SliderContract` on a host: its value kept inside its range, the user's move heard once and landing on the state,
/// the program's travelling there heard by nobody.
@_spi(Host) public enum SliderTests: ConformanceFamily {
    public static let name = "Slider"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSliderShowsItsRangeAndItsValue", covers: [
                Covered(SliderContract.self), Covered(SliderContract.value), Covered(SliderContract.minimum),
                Covered(SliderContract.maximum),
            ]) { s in
                let level = State(wrappedValue: 2.5)
                s.start { VStack { Slider(level.projectedValue).minimum(0).maximum(10).id("slider") } }
                let slider = try s.element("slider")

                s.expect(try s.held(SliderContract.minimum, on: slider), 0)
                s.expect(try s.held(SliderContract.maximum, on: slider), 10)
                s.expect(try s.held(SliderContract.value, on: slider), 2.5, within: 1e-9)
            },
            ConformanceCase("aRangeTheTreeChangesKeepsTheThumbsValue", covers: [
                Covered(SliderContract.value), Covered(SliderContract.maximum), Covered(ButtonContract.clicked),
            ]) { s in
                let top = State(wrappedValue: 10.0)
                let level = State(wrappedValue: 4.0)
                s.start {
                    VStack {
                        Slider(level.projectedValue).minimum(0).maximum(top.wrappedValue).id("slider")
                        Button("Narrow").onClicked { top.wrappedValue = 8 }.id("narrow")
                    }
                }
                let slider = try s.element("slider")

                try s.perform(.activate, on: s.element("narrow"))
                try s.settle { try s.held(SliderContract.maximum, on: slider) == 8 }

                s.expect(try s.held(SliderContract.maximum, on: slider), 8)
                s.expect(try s.held(SliderContract.value, on: slider), 4, within: 1e-9)
            },
            ConformanceCase("aRangeWidenedOverItsValueShowsIt", covers: [
                Covered(SliderContract.value), Covered(SliderContract.maximum), Covered(ButtonContract.clicked),
            ]) { s in
                let top = State(wrappedValue: 10.0)
                let level = State(wrappedValue: 15.0)
                s.start {
                    VStack {
                        Slider(level.projectedValue).minimum(0).maximum(top.wrappedValue).id("control")
                        Button("Widen").onClicked { top.wrappedValue = 20 }.id("widen")
                    }
                }
                let control = try s.element("control")
                try s.settle { try s.held(SliderContract.value, on: control) == 10 }

                try s.perform(.activate, on: s.element("widen"))
                try s.settle { try s.held(SliderContract.maximum, on: control) == 20 }
                try s.settle { try s.held(SliderContract.value, on: control) == 15 }
                s.expect(try s.held(SliderContract.value, on: control), 15, "the value its state holds, no longer at an end")
                s.expect(level.wrappedValue, 15)
            },
            ConformanceCase("aRangeMovedPastItsValueTakesTheValueWrittenWithIt", covers: [
                Covered(SliderContract.value), Covered(SliderContract.minimum), Covered(SliderContract.maximum),
                Covered(SliderContract.valueChanged), Covered(ButtonContract.clicked),
            ]) { s in
                let range = State(wrappedValue: 0.0...10.0)
                let level = State(wrappedValue: 4.0)
                let heard = Received<Double>()
                s.start {
                    VStack {
                        Slider(level.projectedValue).minimum(range.wrappedValue.lowerBound)
                            .maximum(range.wrappedValue.upperBound).onValueChanged { heard.values.append($0) }.id("slider")
                        Button("Up").onClicked {
                            range.wrappedValue = 20...30
                            level.wrappedValue = 25
                        }.id("up")
                        Button("Down").onClicked {
                            range.wrappedValue = -30 ... -20
                            level.wrappedValue = -25
                        }.id("down")
                    }
                }
                let slider = try s.element("slider")

                try s.perform(.activate, on: s.element("up"))
                try s.settle { try s.held(SliderContract.minimum, on: slider) == 20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(SliderContract.value, on: slider) == 25 }
                s.expect(try s.held(SliderContract.value, on: slider), 25, within: 1e-9, "wholly above the value")
                try s.perform(.activate, on: s.element("down"))
                try s.settle { try s.held(SliderContract.maximum, on: slider) == -20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(SliderContract.value, on: slider) == -25 }
                s.expect(try s.held(SliderContract.value, on: slider), -25, within: 1e-9, "wholly below the value")
                s.expect(level.wrappedValue, -25)
                s.expect(heard.values, [], "the program's writes are heard by nobody")
            },
            ConformanceCase("aStateWriteTravelsToTheThumbUnheard", covers: [
                Covered(SliderContract.value), Covered(SliderContract.valueChanged), Covered(ButtonContract.clicked),
            ]) { s in
                let clock = TestClock()
                let level = State(wrappedValue: 0.25)
                let heard = Received<Double>()
                s.start(clock: clock) {
                    VStack {
                        Slider(level.projectedValue).onValueChanged { heard.values.append($0) }.id("slider")
                        Button("Full").onClicked { level.wrappedValue = 1 }.id("full")
                    }
                }
                let slider = try s.element("slider")

                try s.perform(.activate, on: s.element("full"))
                for time in stride(from: 16.0, through: 2_000, by: 16) {
                    clock.now = time
                    s.frame()
                }

                s.expect(try s.held(SliderContract.value, on: slider), 1, within: 1e-9, "the thumb travelled to it")
                s.expect(heard.values, [], "and no frame of its journey was heard as the user's")
            },
            ConformanceCase("aUsersMoveTakesTheJourneyAndIsHeard", covers: [
                Covered(SliderContract.value), Covered(SliderContract.valueChanged),
                Covered(TextElementContract.text, on: LabelContract.self),
            ]) { s in
                let level = State(wrappedValue: 0.0)
                let moves = Received<Double>()
                s.start {
                    VStack {
                        Label("level \(level.wrappedValue)").id("label")
                        Slider(level.projectedValue).onValueChanged { moves.values.append($0) }.id("slider")
                    }
                }
                let slider = try s.element("slider")

                try s.perform(.slide(to: 0.75), on: slider)
                s.settle { level.wrappedValue == 0.75 }

                s.expect(level.wrappedValue, 0.75, within: 1e-9, "the journey took the thumb's value")
                s.expect(moves.values, [0.75], "and the handler heard it once")
                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "level 0.75")
                s.expect(try s.held(SliderContract.value, on: slider), 0.75, within: 1e-9,
                         "the render left the thumb where the hand put it")
            },
            ConformanceCase("aDragIsHeardAsItStartsAndAsItEnds", covers: [
                Covered(SliderContract.dragStarted), Covered(SliderContract.dragCompleted),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Slider(0.5)
                            .onEvent(SliderContract.dragStarted) { heard.values.append("started") }
                            .onEvent(SliderContract.dragCompleted) { heard.values.append("completed") }
                            .width(200).id("slider")
                    }
                    .horizontalAlignment(.start)
                }
                let slider = try s.element("slider")

                try s.perform(.pressDown(at: Point(100, 10)), on: slider)
                s.settle { heard.values == ["started"] }
                s.expect(heard.values, ["started"], "heard as it starts, before it ends")
                try s.perform(.drag(to: Point(150, 10)), on: slider)
                try s.perform(.lift(at: Point(150, 10)), on: slider)
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["started", "completed"])
            },
            ConformanceCase("aValueOutsideItsRangeStandsAtTheNearestEnd", covers: [
                Covered(SliderContract.value), Covered(SliderContract.minimum), Covered(SliderContract.maximum),
            ]) { s in
                s.start {
                    VStack {
                        Slider(15).minimum(0).maximum(10).id("over")
                        Slider(-5).minimum(0).maximum(10).id("under")
                    }
                }

                s.expect(try s.held(SliderContract.value, on: s.element("over")), 10, within: 1e-9)
                s.expect(try s.held(SliderContract.value, on: s.element("under")), 0, within: 1e-9)
            },
            Aspects.holds(SliderContract.minimum, on: "Slider", 0, then: -10),
            Aspects.holds(SliderContract.maximum, on: "Slider", 1, then: 100),
        ]
    }
}
