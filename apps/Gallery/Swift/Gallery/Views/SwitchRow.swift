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

/// The row of controls a sample offers - switches, buttons, or both.
///
///     Options {
///         SwitchRow("Runs sideways", $sideways)
///         SwitchRow("Swiping locked", $locked)
///     }
///
/// A LINE THAT WRAPS RATHER THAN ONE THAT RUNS OFF THE EDGE. A phone is half
/// the width of the window a sample is written in, and a row of three options
/// laid out as a stack simply loses the third one there - it is placed, drawn
/// past the edge and never seen. A FlexLayout puts what does not fit on the
/// next line instead, so the same sample reads on both.
struct Options: ContentView {
    private let rows: [Element]

    /// - Parameter rows: The controls, in the order they are offered.
    init(@ViewBuilder _ rows: () -> [Element]) {
        self.rows = rows()
    }

    var content: Element {
        // MEASURED, because the alternative is drawing off the edge. A row of
        // controls laid out as a stack is placed whether it fits or not, and
        // what does not fit is clipped away with nothing said - which is how a
        // window narrowed to a phone's width loses the third option and every
        // reader of that page with it.
        FrameReader { frame in
            if frame.width > 0 && frame.width < Double(rows.count) * Self.each {
                VStack {
                    rows
                }
                .spacing(4)
                .horizontalOptions(.center)
            } else {
                HStack {
                    rows
                }
                .spacing(16)
                .horizontalOptions(.center)
            }
        }
    }

    /// How much width one option is taken to want, in device units.
    ///
    /// A caption of two or three words, the control beside it and the gap to
    /// the next - measured from the widest of the gallery's own. It decides
    /// ONE thing, which way the options run, so an option wider than this
    /// costs a line that was not needed rather than a control nobody can see.
    private static let each = 200.0
}
