// One on/off option: what it is called, and the switch that answers it.

import StateUI

/// An option a user turns on and off, written as the control that means
/// exactly that: a `Switch` and the words it says beside it.
///
///     SwitchRow("Runs sideways", $sideways)
///
/// A BUTTON IS NOT AN OPTION. A button whose caption changes to say what it
/// would do next - "Lock swiping" / "Unlock swiping" - makes the user work
/// out which of the two words is the state and which is the offer, and a page
/// of them reads as a row of unrelated actions. A switch shows the state and
/// the offer at once, which is what it is for. A button is for something that
/// HAPPENS: Back, Next, Refill.
struct SwitchRow: View {
    private let text: String

    private let value: Binding<Bool>

    /// - Parameters:
    ///   - text: What the option is called.
    ///   - value: The state it is thrown from, and written back to.
    init(_ text: String, _ value: Binding<Bool>) {
        self.text = text
        self.value = value
    }

    var body: some View {
        Switch(value)
            .text(text)
            // The words name the switch; the handle is worked out from them -
            // Handle.swift.
            .accessibilityIdentifier(handle("switch", text))
    }
}