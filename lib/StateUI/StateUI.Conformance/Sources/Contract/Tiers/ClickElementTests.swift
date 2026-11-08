// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ClickElementContract` on a host, on each element wearing the tier, in the place it stands.
@_spi(Host) public enum ClickElementTests: ConformanceFamily {
    public static let name = "ClickElement"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Button.eachClickIsHeardOnceAndRendersWhatItsHandlerChanged", proves: [
                Covered(ClickElementContract.clicked, on: ButtonContract.self),
            ], needs: [Covered(TextElementContract.text, on: TextContract.self)]) { s in
                let count = State(wrappedValue: 0)
                let heard = Received<Int>()
                s.start {
                    VStack {
                        Text("count \(count.wrappedValue)").id("label")
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
            ConformanceCase("Link.aChosenLinkIsHeardOnce", proves: [Covered(ClickElementContract.clicked, on: LinkContract.self)]) { s in
                let heard = Received<Bool>()
                s.start {
                    VStack {
                        Link("Swift", address: "https://www.swift.org/about")
                            .onClicked { heard.values.append(true) }
                            .id("link")
                    }
                }

                try s.perform(.activate, on: s.element("link"))
                s.settle { !heard.values.isEmpty }
                s.expect(heard.values, [true], "its handler ran once")
            },
        ] + Specimens.wearing(ActionElementContract.self).map(ActionElementTests.chosen)
            + (ButtonTests.written + LinkTests.written).proving(ClickElementContract.self)
    }
}
