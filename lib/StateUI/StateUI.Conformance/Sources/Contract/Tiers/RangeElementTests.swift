// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `RangeElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum RangeElementTests: ConformanceFamily {
    public static let name = "RangeElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Slider.aSliderShowsItsRangeAndItsValue", proves: [
                Covered(RangeElementContract.value, on: SliderContract.self), Covered(RangeElementContract.minimum, on: SliderContract.self),
                Covered(RangeElementContract.maximum, on: SliderContract.self),
            ]) { s in
                let level = State(wrappedValue: 2.5)
                s.start { VStack { Slider(level.projectedValue).minimum(0).maximum(10).id("slider") } }
                let slider = try s.element("slider")

                s.expect(try s.held(RangeElementContract.minimum, on: slider), 0)
                s.expect(try s.held(RangeElementContract.maximum, on: slider), 10)
                s.expect(try s.held(RangeElementContract.value, on: slider), 2.5, within: 1e-9)
            },
            ConformanceCase("Slider.aRangeTheTreeChangesKeepsTheThumbsValue", proves: [
                Covered(RangeElementContract.value, on: SliderContract.self), Covered(RangeElementContract.maximum, on: SliderContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
                try s.settle { try s.held(RangeElementContract.maximum, on: slider) == 8 }

                s.expect(try s.held(RangeElementContract.maximum, on: slider), 8)
                s.expect(try s.held(RangeElementContract.value, on: slider), 4, within: 1e-9)
            },
            ConformanceCase("Slider.aRangeWidenedOverItsValueShowsIt", proves: [
                Covered(RangeElementContract.value, on: SliderContract.self), Covered(RangeElementContract.maximum, on: SliderContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let top = State(wrappedValue: 10.0)
                let level = State(wrappedValue: 15.0)
                s.start {
                    VStack {
                        Slider(level.projectedValue).minimum(0).maximum(top.wrappedValue).id("control")
                        Button("Widen").onClicked { top.wrappedValue = 20 }.id("widen")
                    }
                }
                let control = try s.element("control")
                try s.settle { try s.held(RangeElementContract.value, on: control) == 10 }

                try s.perform(.activate, on: s.element("widen"))
                try s.settle { try s.held(RangeElementContract.maximum, on: control) == 20 }
                try s.settle { try s.held(RangeElementContract.value, on: control) == 15 }
                s.expect(try s.held(RangeElementContract.value, on: control), 15, "the value its state holds, no longer at an end")
                s.expect(level.wrappedValue, 15)
            },
            ConformanceCase("Slider.aRangeMovedPastItsValueTakesTheValueWrittenWithIt", proves: [
                Covered(RangeElementContract.value, on: SliderContract.self), Covered(RangeElementContract.minimum, on: SliderContract.self), Covered(RangeElementContract.maximum, on: SliderContract.self),
                Covered(RangeElementContract.valueChanged, on: SliderContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
                try s.settle { try s.held(RangeElementContract.minimum, on: slider) == 20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(RangeElementContract.value, on: slider) == 25 }
                s.expect(try s.held(RangeElementContract.value, on: slider), 25, within: 1e-9, "wholly above the value")
                try s.perform(.activate, on: s.element("down"))
                try s.settle { try s.held(RangeElementContract.maximum, on: slider) == -20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(RangeElementContract.value, on: slider) == -25 }
                s.expect(try s.held(RangeElementContract.value, on: slider), -25, within: 1e-9, "wholly below the value")
                s.expect(level.wrappedValue, -25)
                s.turn()
                s.expect(heard.values, [], "the program's writes are heard by nobody")
            },
            ConformanceCase("Slider.aStateWriteTravelsToTheThumbUnheard", proves: [
                Covered(RangeElementContract.value, on: SliderContract.self), Covered(RangeElementContract.valueChanged, on: SliderContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
                s.frames(of: clock, until: 2_000)

                s.expect(try s.held(RangeElementContract.value, on: slider), 1, within: 1e-9, "the thumb traveled to it")
                s.turn()
                s.expect(heard.values, [], "and no frame of its journey was heard as the user's")
            },
            ConformanceCase("Slider.aUsersMoveTakesTheJourneyAndIsHeard", proves: [
                Covered(RangeElementContract.value, on: SliderContract.self),
                Covered(RangeElementContract.valueChanged, on: SliderContract.self),
            ], needs: [Covered(TextElementContract.text, on: TextContract.self)]) { s in
                let level = State(wrappedValue: 0.0)
                let moves = Received<Double>()
                s.start {
                    VStack {
                        Text("level \(level.wrappedValue)").id("label")
                        Slider(level.projectedValue).onValueChanged { moves.values.append($0) }.id("slider")
                    }
                }
                let slider = try s.element("slider")

                try s.perform(.slide(to: 0.75), on: slider)
                s.settle { level.wrappedValue == 0.75 }

                s.expect(level.wrappedValue, 0.75, within: 1e-9, "the journey took the thumb's value")
                s.expect(moves.values, [0.75], "and the handler heard it once")
                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "level 0.75")
                s.expect(try s.held(RangeElementContract.value, on: slider), 0.75, within: 1e-9,
                         "the render left the thumb where the hand put it")
            },
            ConformanceCase("Slider.aValueOutsideItsRangeStandsAtTheNearestEnd", proves: [
                Covered(RangeElementContract.value, on: SliderContract.self), Covered(RangeElementContract.minimum, on: SliderContract.self), Covered(RangeElementContract.maximum, on: SliderContract.self),
            ]) { s in
                s.start {
                    VStack {
                        Slider(15).minimum(0).maximum(10).id("over")
                        Slider(-5).minimum(0).maximum(10).id("under")
                    }
                }

                s.expect(try s.held(RangeElementContract.value, on: s.element("over")), 10, within: 1e-9)
                s.expect(try s.held(RangeElementContract.value, on: s.element("under")), 0, within: 1e-9)
            },
            Aspects.holds(RangeElementContract.minimum, on: "Slider", 0, then: -10),
            Aspects.holds(RangeElementContract.maximum, on: "Slider", 1, then: 100),
            ConformanceCase("Stepper.typedWordsThatSayNoNumberLeaveTheNumber", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self), Covered(RangeElementContract.valueChanged, on: StepperContract.self), Covered(RangeElementContract.maximum, on: StepperContract.self),
            ]) { s in
                let count = State(wrappedValue: 4.0)
                let heard = Received<Double>()
                s.start {
                    VStack {
                        Stepper(count.projectedValue).minimum(2).maximum(10).step(1)
                            .onValueChanged { heard.values.append($0) }.id("stepper")
                    }
                }
                let stepper = try s.element("stepper")

                for words in ["", "  ", "abc", "5x"] {
                    try s.perform(.enterWords(words), on: stepper)
                    s.turn()
                    s.expect(count.wrappedValue, 4, "'\(words)' left the number")
                    s.expect(try s.held(RangeElementContract.value, on: stepper), 4)
                }
                s.expect(heard.values, [], "words that say no number are heard by nobody")

                try s.perform(.enterWords("20"), on: stepper)
                s.settle { count.wrappedValue == 10 }
                s.expect(count.wrappedValue, 10, "a number typed past an end stands at that end")
                s.expect(heard.values, [10])
            },
            ConformanceCase("Stepper.aStepPastAnEndStaysThereUnheard", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self), Covered(RangeElementContract.minimum, on: StepperContract.self), Covered(RangeElementContract.valueChanged, on: StepperContract.self),
            ]) { s in
                let count = State(wrappedValue: 0.0)
                let heard = Received<Double>()
                s.start {
                    VStack {
                        Stepper(count.projectedValue).minimum(0).maximum(10).step(1)
                            .onValueChanged { heard.values.append($0) }.id("stepper")
                    }
                }
                let stepper = try s.element("stepper")

                try s.perform(.step(up: false), on: stepper)
                s.turn()
                s.expect(count.wrappedValue, 0, "no lower than its minimum")
                s.expect(try s.held(RangeElementContract.value, on: stepper), 0)
                s.expect(heard.values, [], "a step that moved nothing heard by nobody")
            },
            ConformanceCase("Stepper.aRangeWidenedOverItsValueShowsIt", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self), Covered(RangeElementContract.maximum, on: StepperContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let top = State(wrappedValue: 10.0)
                let level = State(wrappedValue: 15.0)
                s.start {
                    VStack {
                        Stepper(level.projectedValue).minimum(0).maximum(top.wrappedValue).step(1).id("control")
                        Button("Widen").onClicked { top.wrappedValue = 20 }.id("widen")
                    }
                }
                let control = try s.element("control")
                try s.settle { try s.held(RangeElementContract.value, on: control) == 10 }

                try s.perform(.activate, on: s.element("widen"))
                try s.settle { try s.held(RangeElementContract.maximum, on: control) == 20 }
                try s.settle { try s.held(RangeElementContract.value, on: control) == 15 }
                s.expect(try s.held(RangeElementContract.value, on: control), 15, "the value its state holds, no longer at an end")
                s.expect(level.wrappedValue, 15)
            },
            ConformanceCase("Stepper.aRangeMovedPastItsValueTakesTheValueWrittenWithIt", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self), Covered(RangeElementContract.minimum, on: StepperContract.self), Covered(RangeElementContract.maximum, on: StepperContract.self),
                Covered(RangeElementContract.valueChanged, on: StepperContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let range = State(wrappedValue: 0.0...10.0)
                let count = State(wrappedValue: 4.0)
                let heard = Received<Double>()
                s.start {
                    VStack {
                        Stepper(count.projectedValue).minimum(range.wrappedValue.lowerBound)
                            .maximum(range.wrappedValue.upperBound).step(1)
                            .onValueChanged { heard.values.append($0) }.id("stepper")
                        Button("Up").onClicked {
                            range.wrappedValue = 20...30
                            count.wrappedValue = 25
                        }.id("up")
                        Button("Down").onClicked {
                            range.wrappedValue = -30 ... -20
                            count.wrappedValue = -25
                        }.id("down")
                    }
                }
                let stepper = try s.element("stepper")

                try s.perform(.activate, on: s.element("up"))
                try s.settle { try s.held(RangeElementContract.minimum, on: stepper) == 20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(RangeElementContract.value, on: stepper) == 25 }
                s.expect(try s.held(RangeElementContract.value, on: stepper), 25, "wholly above the value")
                try s.perform(.activate, on: s.element("down"))
                try s.settle { try s.held(RangeElementContract.maximum, on: stepper) == -20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(RangeElementContract.value, on: stepper) == -25 }
                s.expect(try s.held(RangeElementContract.value, on: stepper), -25, "wholly below the value")
                s.expect(count.wrappedValue, -25)
                s.turn()
                s.expect(heard.values, [], "the program's writes are heard by nobody")
            },
            Aspects.holds(RangeElementContract.minimum, on: "Stepper", 0, then: -5, with: [Write(RangeElementContract.value, 2)]),
            Aspects.holds(RangeElementContract.maximum, on: "Stepper", 10, then: 20, with: [Write(RangeElementContract.value, 2)]),
        ] + StepperTests.written.proving(RangeElementContract.self)
    }
}
