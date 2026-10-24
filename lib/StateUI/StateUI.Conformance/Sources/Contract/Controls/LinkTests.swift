// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LinkContract` on a host: a link the user chooses opens its address as a launched one opens, and its handler runs
/// once - the address a state holds too, as it stands when chosen.
@_spi(Host) public enum LinkTests: ConformanceFamily {
    public static let name = "Link"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Link"),
            ConformanceCase("aChosenLinkIsHeardOnce", proves: [Covered(LinkContract.clicked)]) { s in
                let heard = Received<Bool>()
                s.start {
                    VStack {
                        Link("Swift", destination: "https://www.swift.org/about")
                            .onClicked { heard.values.append(true) }
                            .id("link")
                    }
                }

                try s.perform(.activate, on: s.element("link"))
                s.settle { !heard.values.isEmpty }
                s.expect(heard.values, [true], "its handler ran once")
            },
            ConformanceCase("aChosenLinkOpensItsAddress", proves: [
                Covered(LinkContract.destination),
            ], needs: [Covered(LinkContract.clicked)]) { s in
                s.start { VStack { Link("Swift", destination: "https://www.swift.org/about").id("link") } }

                try s.perform(.activate, on: s.element("link"))
                try s.settle { try s.launched() == ["https://www.swift.org/about"] }
                s.expect(try s.launched(), ["https://www.swift.org/about"], "its address opened")
            },
            ConformanceCase("aLinkOpensTheAddressItsStateHolds", proves: [
                Covered(LinkContract.destination),
            ], needs: [Covered(LinkContract.clicked), Covered(ButtonContract.clicked)]) { s in
                let address = State(wrappedValue: "https://www.swift.org")
                s.start {
                    VStack {
                        Link("Swift", destination: address.projectedValue).id("link")
                        Button("Blog").onClicked { address.wrappedValue = "https://www.swift.org/blog" }.id("change")
                    }
                }

                try s.perform(.activate, on: s.element("change"))
                s.turn()
                try s.perform(.activate, on: s.element("link"))
                try s.settle { try s.launched() == ["https://www.swift.org/blog"] }
                s.expect(try s.launched(), ["https://www.swift.org/blog"], "the address the state holds now")
            },
        ]
    }
}
