// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `StepperContract` on a host: the user's step is heard once and lands on the state, a value kept inside its range,
/// and words that say no number leave the number.
@_spi(Host) public enum StepperTests: ConformanceFamily {
    public static let name = "Stepper"

    public static var cases: [ConformanceCase] { written.proving(StepperContract.self) }

    /// Every case written for the contract: its own members, and a tier's its family takes up.
    @MainActor static var written: [ConformanceCase] {
        [
            Aspects.standsAlone("Stepper"),
            ConformanceCase("aUsersStepIsHeardAndTheProgramsIsNot", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self),
                Covered(RangeElementContract.valueChanged, on: StepperContract.self),
                Covered(RangeElementContract.minimum, on: StepperContract.self),
                Covered(RangeElementContract.maximum, on: StepperContract.self),
                Covered(StepperContract.step),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
                s.expect(try s.held(RangeElementContract.value, on: stepper), 2)

                try s.perform(.step(up: true), on: stepper)
                s.settle { count.wrappedValue == 3 }
                s.expect(count.wrappedValue, 3)
                s.expect(heard.values, [3])

                try s.perform(.activate, on: s.element("more"))
                try s.settle { try s.held(RangeElementContract.value, on: stepper) == 10 }
                s.expect(try s.held(RangeElementContract.value, on: stepper), 10, "kept inside its range")
                s.expect(heard.values, [3], "and nobody heard the program")
            },
            ConformanceCase("aFractionalStepLandsOnItsDecimals", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self), Covered(StepperContract.step),
            ]) { s in
                let level = State(wrappedValue: 0.2)
                let heard = Received<Double>()
                s.start {
                    Stepper(level.projectedValue).minimum(0).maximum(1).step(0.1)
                        .onValueChanged { heard.values.append($0) }.id("stepper")
                }
                let stepper = try s.element("stepper")

                try s.perform(.step(up: true), on: stepper)
                s.settle { !heard.values.isEmpty }
                s.expect(level.wrappedValue, 0.3, "a tenth from 0.2 is 0.3, not what binary arithmetic adds up to")
                s.expect(heard.values, [0.3])
            },
            ConformanceCase("itShowsItsStepsAlone", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self), Covered(StepperContract.step),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let count = State(wrappedValue: 2.0)
                s.start {
                    VStack {
                        Stepper(count.projectedValue).minimum(0).maximum(10).step(2).id("stepper")
                        Button("Far").onClicked { count.wrappedValue = 9.2 }.id("far")
                    }
                }
                let stepper = try s.element("stepper")
                var shown: [Double] = []
                try s.perform(.activate, on: s.element("far"))
                try s.settle {
                    let standing = try s.held(RangeElementContract.value, on: stepper) ?? .nan
                    if shown.last != standing { shown.append(standing) }
                    return standing == 9.2
                }
                // Every step of 9.2 from where it set out, and nothing between them.
                s.expect(shown.filter { ![2, 3.2, 5.2, 7.2, 9.2].contains($0) }, [], "shown on its way")
                s.expect(shown.last, 9.2, "the value it was given, at rest")
            },
            ConformanceCase("aStepIsAsLongAsTheTreeSays", proves: [
                Covered(RangeElementContract.value, on: StepperContract.self), Covered(StepperContract.step),
            ]) { s in
                let count = State(wrappedValue: 1.0)
                s.start { VStack { Stepper(count.projectedValue).minimum(0).maximum(10).step(2.5).id("stepper") } }

                try s.perform(.step(up: true), on: s.element("stepper"))
                s.settle { count.wrappedValue == 3.5 }
                s.expect(count.wrappedValue, 3.5)
            },
            Aspects.holds(StepperContract.step, on: "Stepper", 1, then: 0.5, with: [Write(RangeElementContract.value, 2)]),
        ]
    }
}
