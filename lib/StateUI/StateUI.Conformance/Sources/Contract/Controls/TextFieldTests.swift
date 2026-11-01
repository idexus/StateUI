// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TextFieldContract` on a host: a field greets as it is typed into, a password's words are heard as typed, Enter
/// submits it once, and a return saying Next hands the keyboard on.
@_spi(Host) public enum TextFieldTests: ConformanceFamily {
    public static let name = "TextField"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("TextField"),
            ConformanceCase("eachKeystrokeReachesTheStateAndTheGreeting", proves: [
                Covered(TextFieldContract.self),
            ], needs: [
                Covered(TextualElementContract.text, on: TextFieldContract.self),
                Covered(TextualElementContract.text, on: TextContract.self),
            ]) { s in
                let name = State(wrappedValue: "")
                s.start {
                    VStack {
                        Text(name.wrappedValue.isEmpty ? "Hello!" : "Hello, \(name.wrappedValue)!").id("greeting")
                        TextField(name.projectedValue).placeholder("Type your name").id("field")
                    }
                }
                let field = try s.element("field")

                for typed in ["A", "Ad", "Ada"] {
                    try s.perform(.type(typed), on: field)
                    s.settle { name.wrappedValue == typed }
                }

                s.expect(name.wrappedValue, "Ada")
                s.expect(try s.held(TextualElementContract.text, on: field), "Ada")
                s.expect(try s.held(TextualElementContract.text, on: s.element("greeting")), "Hello, Ada!")
            },
            ConformanceCase("enterSubmitsAFieldOnce", proves: [Covered(TextFieldContract.submitted)]) { s in
                let heard = Received<String>()
                s.start { VStack { TextField("").onSubmitted { heard.values.append("submitted") }.id("field") } }

                try s.perform(.submit, on: s.element("field"))
                s.settle { !heard.values.isEmpty }
                s.turn()

                s.expect(heard.values, ["submitted"])
            },
            ConformanceCase("aPasswordsWordsAreHeardAsTyped", proves: [
                Covered(TextFieldContract.isPassword),
            ], needs: [Covered(TextualElementContract.text, on: "TextField")]) { s in
                let secret = State(wrappedValue: "")
                s.start { VStack { TextField(secret.projectedValue).isPassword(true).id("field") } }
                let field = try s.element("field")
                s.expect(try s.held(TextFieldContract.isPassword, on: field), true)

                try s.perform(.type("hunter2"), on: field)
                s.settle { secret.wrappedValue == "hunter2" }
                s.expect(secret.wrappedValue, "hunter2", "a password's words reach the state as any field's")
            },
            Aspects.holds(TextFieldContract.isPassword, on: "TextField", false, then: true),
            Aspects.holds(TextFieldContract.submitLabel, on: "TextField", .done, then: .send),
            handsTheKeyboardOn(from: "TextField", saying: TextFieldContract.submitLabel),
            Aspects.holds(TextFieldContract.showsClearButton, on: "TextField", true, then: false),
            standsAsWideAsItsWords("TextField"),
        ]
    }

    /// A field nothing sizes stands at least as wide as its placeholder, and with none as twenty digits - the words
    /// beside it in a `Text` the measure - whatever the platform's own field asks for.
    /// Design: docs/design/host/layout.md#a-fields-own-width
    @MainActor
    static func standsAsWideAsItsWords(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).standsAsWideAsItsWords", proves: [
            Covered(TextInputContract.placeholder, on: element),
        ], needs: [
            Covered(ViewContract.frameChanged, on: element), Covered(ViewContract.frameChanged, on: "Text"),
        ]) { s in
            for words in ["Search every note, folder and tag", nil] {
                let field = Received<[Double]>(), measure = Received<[Double]>()
                let said = words.map { [Write(TextInputContract.placeholder, $0)] as [any Worn] } ?? []
                s.start {
                    VStack {
                        HStack { ViewTests.reporting(element, field, said) }
                        HStack { ViewTests.reporting("Text", measure, [
                            Write(TextualElementContract.text, words ?? String(repeating: "0", count: 20)),
                        ], id: "measure") }
                    }
                    .horizontalAlignment(.start)
                }

                s.settle { (field.values.last.map(FrameReport.size)?.first ?? 0) > 0 && !measure.values.isEmpty }
                let width = field.values.last.map(FrameReport.size)?.first ?? 0
                let least = measure.values.last.map(FrameReport.size)?.first ?? .infinity
                s.expect(width >= least, true, "\(width) wide beside words \(least) wide - \(words ?? "twenty digits")")
            }
        }
    }
}
