// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ButtonContract` on a host: each click heard once, a press heard as it goes down and as it is let go, and the
/// button's icon, where it stands, how far from the words, and how the words break.
@_spi(Host) public enum ButtonTests: ConformanceFamily {
    public static let name = "Button"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("eachClickIsHeardOnceAndRendersWhatItsHandlerChanged", covers: [
                Covered(ButtonContract.self), Covered(ButtonContract.clicked),
                Covered(TextElementContract.text, on: LabelContract.self),
            ]) { s in
                let count = State(wrappedValue: 0)
                let heard = Received<Int>()
                s.start {
                    VStack {
                        Label("count \(count.wrappedValue)").id("label")
                        Button("Add").onClicked {
                            count.wrappedValue += 1
                            heard.values.append(count.wrappedValue)
                        }.id("button")
                    }
                }
                let button = try s.element("button")

                try s.perform(.activate, on: button)
                try s.settle { try s.held(TextElementContract.text, on: s.element("label")) == "count 1" }
                try s.perform(.activate, on: button)
                try s.settle { try s.held(TextElementContract.text, on: s.element("label")) == "count 2" }

                s.expect(heard.values, [1, 2], "each click heard once")
                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "count 2")
            },
            ConformanceCase("aPressIsHeardAsItGoesDownAndAsItIsLetGo", covers: [
                Covered(ButtonContract.pressed), Covered(ButtonContract.released),
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
            Aspects.holds(ButtonContract.icon, on: "Button", "test_dot.png", then: "test_wide.png",
                          with: [Write(TextElementContract.text, "Go")]),
            Aspects.holds(ButtonContract.iconPosition, on: "Button", .leading, then: .top, with: [
                Write(TextElementContract.text, "Go"), Write(ButtonContract.icon, "test_dot.png"),
            ]),
            Aspects.holds(ButtonContract.iconSpacing, on: "Button", 4, then: 12, with: [
                Write(TextElementContract.text, "Go"), Write(ButtonContract.icon, "test_dot.png"),
            ]),
            Aspects.holds(ButtonContract.lineBreak, on: "Button", .wordWrap, then: .tailTruncation,
                          with: [Write(TextElementContract.text, "Words enough to break across more than one line")]),
        ]
    }
}
