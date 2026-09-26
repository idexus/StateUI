// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `SpanContract` on a host: a span is its label's words, run by run, each changing as the tree changes it, behind
/// the colour the tree gives it.
@_spi(Host) public enum SpanTests: ConformanceFamily {
    public static let name = "Span"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aLabelsSpansAreItsWordsRunByRun", covers: [
                Covered(SpanContract.self), Covered(TextElementContract.text, on: "Span"),
            ]) { s in
                s.start {
                    VStack {
                        Label().spans {
                            TextSpan("let ")
                            TextSpan("x")
                            TextSpan(" = 1")
                        }.id("label")
                    }
                }

                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "let x = 1")
                s.expect(s.elements(ofType: SpanContract.nodeType).count, 3, "a span a run")
            },
            ConformanceCase("aSpanTheTreeChangesChangesItsRun", covers: [
                Covered(TextElementContract.text, on: "Span"), Covered(ButtonContract.clicked),
            ]) { s in
                let changed = State(wrappedValue: false)
                s.start {
                    VStack {
                        Label().spans {
                            TextSpan("let ")
                            TextSpan(changed.wrappedValue ? "y" : "x")
                        }.id("label")
                        Button("Change").onClicked { changed.wrappedValue = true }.id("change")
                    }
                }
                let label = try s.element("label")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.held(TextElementContract.text, on: label) == "let y" }
                s.expect(try s.held(TextElementContract.text, on: label), "let y")
            },
            Aspects.holds(SpanContract.background, on: "Span", .yellow, then: .cyan),
        ]
    }
}
