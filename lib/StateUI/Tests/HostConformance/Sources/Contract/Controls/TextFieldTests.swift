// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `TextFieldContract` on a host: a field greets as it is typed into, and Enter submits it once.
@_spi(Host) public enum TextFieldTests: ConformanceFamily {
    public static let name = "TextField"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("eachKeystrokeReachesTheStateAndTheGreeting", covers: [
                Covered(TextFieldContract.self), Covered(TextElementContract.text, on: TextFieldContract.self),
                Covered(TextElementContract.text, on: LabelContract.self),
            ]) { s in
                let name = State(wrappedValue: "")
                s.start {
                    VStack {
                        Label(name.wrappedValue.isEmpty ? "Hello!" : "Hello, \(name.wrappedValue)!").id("greeting")
                        TextField(name.projectedValue).placeholder("Type your name").id("field")
                    }
                }
                let field = try s.element("field")

                for typed in ["A", "Ad", "Ada"] {
                    try s.perform(.type(typed), on: field)
                    s.settle { name.wrappedValue == typed }
                }

                s.expect(name.wrappedValue, "Ada")
                s.expect(try s.held(TextElementContract.text, on: field), "Ada")
                s.expect(try s.held(TextElementContract.text, on: s.element("greeting")), "Hello, Ada!")
            },
            ConformanceCase("enterSubmitsAFieldOnce", covers: [Covered(TextFieldContract.submitted)]) { s in
                let heard = Received<String>()
                s.start { VStack { TextField("").onSubmitted { heard.values.append("submitted") }.id("field") } }

                try s.perform(.submit, on: s.element("field"))
                s.settle { !heard.values.isEmpty }
                s.turn()

                s.expect(heard.values, ["submitted"])
            },
            ConformanceCase("aPasswordsWordsAreHeardAsTyped", covers: [
                Covered(TextFieldContract.isPassword), Covered(TextElementContract.text, on: "TextField"),
            ]) { s in
                let secret = State(wrappedValue: "")
                s.start { VStack { TextField(secret.projectedValue).isPassword(true).id("field") } }
                let field = try s.element("field")
                s.expect(try s.held(TextFieldContract.isPassword, on: field), true)

                try s.perform(.type("hunter2"), on: field)
                s.settle { secret.wrappedValue == "hunter2" }
                s.expect(secret.wrappedValue, "hunter2", "a password's words reach the state as any field's")
            },
            Aspects.holds(TextFieldContract.isPassword, on: "TextField", false, then: true),
            Aspects.holds(TextFieldContract.returnKey, on: "TextField", .done, then: .send),
            Aspects.holds(TextFieldContract.showsClearButton, on: "TextField", true, then: false),
        ]
    }
}
