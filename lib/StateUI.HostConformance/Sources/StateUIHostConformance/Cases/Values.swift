// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a slider, a stepper, a progress bar and a spinner do: a value kept inside its range, the user's change heard
/// once and landing on the state, the program's travelling there heard by nobody.
@_spi(Host) public enum Values: ConformanceFamily {
    public static let name = "Values"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSliderShowsItsRangeAndItsValue", covers: [
                Covered(SliderContract.value), Covered(SliderContract.minimum), Covered(SliderContract.maximum),
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
            ConformanceCase("aUsersStepIsHeardAndTheProgramsIsNot", covers: [
                Covered(StepperContract.value), Covered(StepperContract.valueChanged), Covered(StepperContract.minimum),
                Covered(StepperContract.maximum), Covered(StepperContract.step), Covered(ButtonContract.clicked),
            ]) { s in
                let count = State(wrappedValue: 2.0)
                let heard = Received<Double>()
                s.start {
                    VStack {
                        Stepper(count.projectedValue).minimum(0).maximum(10).step(1)
                            .onValueChanged { heard.values.append($0) }.id("stepper")
                        Button("Too many").onClicked { count.wrappedValue = 20 }.id("more")
                    }
                }
                let stepper = try s.element("stepper")
                s.expect(try s.held(StepperContract.value, on: stepper), 2)

                try s.perform(.step(up: true), on: stepper)
                s.settle { count.wrappedValue == 3 }
                s.expect(count.wrappedValue, 3)
                s.expect(heard.values, [3])

                try s.perform(.activate, on: s.element("more"))
                try s.settle { try s.held(StepperContract.value, on: stepper) == 10 }
                s.expect(try s.held(StepperContract.value, on: stepper), 10, "kept inside its range")
                s.expect(heard.values, [3], "and nobody heard the program")
            },
            ConformanceCase("typedWordsThatSayNoNumberLeaveTheNumber", covers: [
                Covered(StepperContract.value), Covered(StepperContract.valueChanged), Covered(StepperContract.maximum),
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
                    s.expect(try s.held(StepperContract.value, on: stepper), 4)
                }
                s.expect(heard.values, [], "words that say no number are heard by nobody")

                try s.perform(.enterWords("20"), on: stepper)
                s.settle { count.wrappedValue == 10 }
                s.expect(count.wrappedValue, 10, "a number typed past an end stands at that end")
                s.expect(heard.values, [10])
            },
            ConformanceCase("aBarStandsAtItsShareOfTheWorkWithinItsEnds", covers: [
                Covered(ProgressBarContract.progress),
            ]) { s in
                s.start {
                    VStack {
                        ProgressBar(0.5).id("half")
                        ProgressBar(1.5).id("over")
                        ProgressBar(-1).id("under")
                    }
                }

                s.expect(try s.held(ProgressBarContract.progress, on: s.element("half")), 0.5, within: 1e-9)
                s.expect(try s.held(ProgressBarContract.progress, on: s.element("over")), 1, within: 1e-9)
                s.expect(try s.held(ProgressBarContract.progress, on: s.element("under")), 0, within: 1e-9)
            },
            ConformanceCase("aSpinnerTurnsWhileItsWorkRuns", covers: [
                Covered(ActivityIndicatorContract.isRunning), Covered(ButtonContract.clicked),
            ]) { s in
                let running = State(wrappedValue: true)
                s.start {
                    VStack {
                        ActivityIndicator(running.wrappedValue).id("spinner")
                        Button("Stop").onClicked { running.wrappedValue = false }.id("stop")
                    }
                }
                let spinner = try s.element("spinner")
                s.expect(try s.held(ActivityIndicatorContract.isRunning, on: spinner), true)

                try s.perform(.activate, on: s.element("stop"))
                try s.settle { try s.held(ActivityIndicatorContract.isRunning, on: spinner) == false }

                s.expect(try s.held(ActivityIndicatorContract.isRunning, on: spinner), false)
            },
        ]
    }
}
