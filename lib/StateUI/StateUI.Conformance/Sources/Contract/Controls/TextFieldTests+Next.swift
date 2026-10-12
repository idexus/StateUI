// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A field whose return says Next, submitted, hands the keyboard on - the case every field with a return key wears.
/// Design: docs/design/types/keyboard.md#the-next-field
extension TextFieldTests {
    /// `element`'s return saying Next - `label` - hands the keyboard, as it submits, to the next field its page
    /// reads, past what is no field and a field disabled.
    @MainActor
    static func handsTheKeyboardOn<Owner: ElementContract>(
        from element: String, saying label: ElementProperty<Owner, SubmitLabel>
    ) -> ConformanceCase {
        ConformanceCase("\(element).aReturnSayingNextHandsTheKeyboardOn", proves: [
            Covered(label),
        ], needs: [Covered(FocusElementContract.focus, on: element)]) { s in
            s.start {
                VStack {
                    Specimens.view(element, [Write(label, SubmitLabel.next)], id: "first")
                    Text("Between")
                    TextField("").isEnabled(false).id("off")
                    TextField("").id("second")
                }
            }
            let first = try s.element("first")
            let second = try s.element("second")

            try s.perform(.focus, on: first)
            try s.settle { try s.focused(first) }
            try s.perform(.submit, on: first)
            try s.settle { try s.focused(second) }
            s.expect(try s.focused(second), true, "the next field the page reads, past one disabled")
        }
    }
}
