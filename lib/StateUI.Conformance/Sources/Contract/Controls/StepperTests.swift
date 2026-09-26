// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `StepperContract` on a host: the user's step is heard once and lands on the state, a value kept inside its range,
/// and words that say no number leave the number.
@_spi(Host) public enum StepperTests: ConformanceFamily {
    public static let name = "Stepper"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aUsersStepIsHeardAndTheProgramsIsNot", covers: [
                Covered(StepperContract.self), Covered(StepperContract.value), Covered(StepperContract.valueChanged),
                Covered(StepperContract.minimum), Covered(StepperContract.maximum), Covered(StepperContract.step),
                Covered(ButtonContract.clicked),
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
            ConformanceCase("aStepPastAnEndStaysThereUnheard", covers: [
                Covered(StepperContract.value), Covered(StepperContract.minimum), Covered(StepperContract.valueChanged),
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
                s.expect(try s.held(StepperContract.value, on: stepper), 0)
                s.expect(heard.values, [], "a step that moved nothing heard by nobody")
            },
            ConformanceCase("aRangeWidenedOverItsValueShowsIt", covers: [
                Covered(StepperContract.value), Covered(StepperContract.maximum), Covered(ButtonContract.clicked),
            ]) { s in
                let top = State(wrappedValue: 10.0)
                let level = State(wrappedValue: 15.0)
                s.start {
                    VStack {
                        Stepper(level.projectedValue).minimum(0).maximum(top.wrappedValue).step(1).id("control")
                        Button("Widen").onClicked { top.wrappedValue = 20 }.id("widen")
                    }
                }
                let control = try s.element("control")
                try s.settle { try s.held(StepperContract.value, on: control) == 10 }

                try s.perform(.activate, on: s.element("widen"))
                try s.settle { try s.held(StepperContract.maximum, on: control) == 20 }
                try s.settle { try s.held(StepperContract.value, on: control) == 15 }
                s.expect(try s.held(StepperContract.value, on: control), 15, "the value its state holds, no longer at an end")
                s.expect(level.wrappedValue, 15)
            },
            ConformanceCase("aRangeMovedPastItsValueTakesTheValueWrittenWithIt", covers: [
                Covered(StepperContract.value), Covered(StepperContract.minimum), Covered(StepperContract.maximum),
                Covered(StepperContract.valueChanged), Covered(ButtonContract.clicked),
            ]) { s in
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
                try s.settle { try s.held(StepperContract.minimum, on: stepper) == 20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(StepperContract.value, on: stepper) == 25 }
                s.expect(try s.held(StepperContract.value, on: stepper), 25, "wholly above the value")
                try s.perform(.activate, on: s.element("down"))
                try s.settle { try s.held(StepperContract.maximum, on: stepper) == -20 }
                // The state's write travels to the control, standing at the range's end on its way.
                try s.settle { try s.held(StepperContract.value, on: stepper) == -25 }
                s.expect(try s.held(StepperContract.value, on: stepper), -25, "wholly below the value")
                s.expect(count.wrappedValue, -25)
                s.expect(heard.values, [], "the program's writes are heard by nobody")
            },
            ConformanceCase("aStepIsAsLongAsTheTreeSays", covers: [
                Covered(StepperContract.step), Covered(StepperContract.value), Covered(StepperContract.valueChanged),
            ]) { s in
                let count = State(wrappedValue: 1.0)
                s.start { VStack { Stepper(count.projectedValue).minimum(0).maximum(10).step(2.5).id("stepper") } }

                try s.perform(.step(up: true), on: s.element("stepper"))
                s.settle { count.wrappedValue == 3.5 }
                s.expect(count.wrappedValue, 3.5)
            },
            Aspects.holds(StepperContract.minimum, on: "Stepper", 0, then: -5, with: [Write(StepperContract.value, 2)]),
            Aspects.holds(StepperContract.maximum, on: "Stepper", 10, then: 20, with: [Write(StepperContract.value, 2)]),
            Aspects.holds(StepperContract.step, on: "Stepper", 1, then: 0.5, with: [Write(StepperContract.value, 2)]),
        ]
    }
}
