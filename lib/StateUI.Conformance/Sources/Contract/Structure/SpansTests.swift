// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SpansContract` on a host: a label given spans shows their words in place of its own, and its own again once the
/// tree takes them away.
@_spi(Host) public enum SpansTests: ConformanceFamily {
    public static let name = "Spans"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aLabelsSpansStandInPlaceOfItsOwnWords", covers: [
                Covered(SpansContract.self), Covered(ButtonContract.clicked),
            ]) { s in
                let spanned = State(wrappedValue: true)
                s.start {
                    VStack {
                        if spanned.wrappedValue {
                            Label("own").spans { TextSpan("runs") }.id("words")
                        } else {
                            Label("own").id("words")
                        }
                        Button("Plain").onClicked { spanned.wrappedValue = false }.id("change")
                    }
                }
                s.expect(try s.held(TextElementContract.text, on: s.element("words")), "runs")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(TextElementContract.text, on: s.element("words")) == "own" }
                s.expect(try s.held(TextElementContract.text, on: s.element("words")), "own", "its own words again")
            },
        ]
    }
}
