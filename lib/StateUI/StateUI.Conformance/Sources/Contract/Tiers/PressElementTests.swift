// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PressElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum PressElementTests: ConformanceFamily {
    public static let name = "PressElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Button.aPressIsHeardAsItGoesDownAndAsItIsLetGo", proves: [
                Covered(PressElementContract.pressed, on: ButtonContract.self), Covered(PressElementContract.released, on: ButtonContract.self),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Button("Hold")
                            .onPressed { heard.values.append("pressed") }
                            .onReleased { heard.values.append("released") }
                            .width(120).height(40).id("button")
                    }
                    .horizontalAlignment(.start)
                }
                let button = try s.element("button")

                try s.perform(.pressDown(at: Point(60, 20)), on: button)
                s.settle { heard.values == ["pressed"] }
                s.expect(heard.values, ["pressed"], "heard as it goes down, before it is let go")

                try s.perform(.lift(at: Point(60, 20)), on: button)
                s.settle { heard.values.count == 2 }
                s.expect(heard.values, ["pressed", "released"])
            },
            ConformanceCase("Slider.aDragIsHeardAsItStartsAndAsItEnds", proves: [
                Covered(PressElementContract.pressed, on: SliderContract.self), Covered(PressElementContract.released, on: SliderContract.self),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        Slider(0.5)
                            .onEvent(PressElementContract.pressed) { heard.values.append("started") }
                            .onEvent(PressElementContract.released) { heard.values.append("completed") }
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
        ] + ["ToolbarButton", "ToolbarToggle"].map(pressed)
    }

    /// A press on a button shows its pressed values while it holds, and letting go gives its own back.
    @MainActor
    static func pressed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).followsAPressOnIt", proves: [
            Covered(PressElementContract.pressed, on: element), Covered(PressElementContract.released, on: element),
        ], needs: [Covered(BackgroundElementContract.background, on: element)]) { s in
            s.start { BarItemStates.page(element, .pressed) }
            let button = try s.element("specimen")
            let background = { try s.held(BackgroundElementContract.background, on: button) }
            try s.settle { try background() == .color(.steelBlue) }

            try s.perform(.pressDown(at: Point(8, 8)), on: button)
            try s.settle { try background() == .color(.firebrick) }
            s.expect(try background(), .color(.firebrick), "its pressed background while the press holds")

            try s.perform(.lift(at: Point(8, 8)), on: button)
            try s.settle { try background() == .color(.steelBlue) }
            s.expect(try background(), .color(.steelBlue), "its own again")
        }
    }
}
