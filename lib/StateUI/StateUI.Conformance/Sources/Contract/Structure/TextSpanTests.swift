// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextSpanContract` on a host: a span is its label's words, run by run, each changing as the tree changes it, behind
/// the color the tree gives it.
@_spi(Host) public enum TextSpanTests: ConformanceFamily {
    public static let name = "TextSpan"

    public static var cases: [ConformanceCase] { written.proving(TextSpanContract.self) }

    /// Every case written for the contract: its own members, and a tier's its family takes up.
    @MainActor static var written: [ConformanceCase] {
        [
            ConformanceCase("aTextsSpansAreItsWordsRunByRun", proves: [
                Covered(TextSpanContract.self),
            ], needs: [Covered(TextElementContract.text, on: "TextSpan")]) { s in
                s.start {
                    VStack {
                        Text().spans {
                            TextSpan("let ")
                            TextSpan("x")
                            TextSpan(" = 1")
                        }.id("label")
                    }
                }

                s.expect(try s.held(TextElementContract.text, on: s.element("label")), "let x = 1")
                let spans = s.elements(ofType: TextSpanContract.nodeType)
                s.expect(try spans.map { try s.held(TextElementContract.text, on: $0) }, ["let ", "x", " = 1"],
                         "a span a run")
            },
            ConformanceCase("aSpanTheTreeChangesChangesItsRun", proves: [
                Covered(TextSpanContract.self),
            ], needs: [Covered(TextElementContract.text, on: "TextSpan"), Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let changed = State(wrappedValue: false)
                s.start {
                    VStack {
                        Text().spans {
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
        ]
    }
}
