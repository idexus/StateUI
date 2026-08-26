// One on/off option: what it is called, and the switch that answers it.

import StateUI

/// An option a reader turns on and off, written as the control that means
/// exactly that: a caption beside a `Switch`.
///
///     SwitchRow("Runs sideways", $sideways)
///
/// A BUTTON IS NOT AN OPTION. A button whose caption changes to say what it
/// would do next - "Lock swiping" / "Unlock swiping" - makes the reader work
/// out which of the two words is the state and which is the offer, and a page
/// of them reads as a row of unrelated actions. A switch shows the state and
/// the offer at once, which is what it is for. A button is for something that
/// HAPPENS: Back, Next, Refill.
struct SwitchRow: ContentView {
    private let text: String

    private let value: Binding<Bool>

    /// - Parameters:
    ///   - text: What the option is called.
    ///   - value: The state it is thrown from, and written back to.
    init(_ text: String, _ value: Binding<Bool>) {
        self.text = text
        self.value = value
    }

    var content: Element {
        HStack {
            Label(text)
                .fontSize(13)
                .verticalOptions(.center)

            Switch(value)
                .verticalOptions(.center)
                // WINDOWS GIVES A SWITCH A MINIMUM WIDTH OF ITS OWN - room for
                // the On/Off words its template can show - and charges it
                // whether or not anything is written there: measured at 154
                // units against the 40 the control draws in. Three options in
                // a row then want 780 units where they need 450, and a narrow
                // window loses the last of them. Nothing is taken away
                // elsewhere: every other platform already measures a switch at
                // what it draws.
                .minimumWidthRequest(0)
        }
        .spacing(8)
    }
}