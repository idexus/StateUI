// The heading above a section.

import StateUI

/// A piece of interface, factored out. MAUI calls this a ContentView, and so
/// does StateUI: give it a `content` and it can be used like any other view.
///
/// Shaped the way every control in the library is: what it SAYS is the
/// initializer's one argument, and everything optional is a modifier. See
/// `Card` for the whole of that rule written out.
struct SectionTitle: ContentView {
    private let text: String

    /// Whether this section shows a TRAP rather than a way to do something.
    private var warned = false

    /// - Parameter text: What the heading says.
    init(_ text: String) {
        self.text = text
    }

    /// Puts the warning triangle beside the words: this section is a trap
    /// rather than a way to do something. A reader who skims the headings must
    /// not take the trap for the recipe.
    func warns(_ value: Bool) -> Self {
        var copy = self
        copy.warned = value
        return copy
    }

    var content: Element {
        guard warned else { return words }

        return HStack {
            WarningMark()
            words
        }
        .spacing(6)
    }

    private var words: Element {
        Label(text)
            .fontSize(13)
            .fontAttributes(.bold)
            .textColor(Palette.subtle)
            .characterSpacing(1)
            .verticalOptions(.center)
    }
}

/// The warning triangle on its own, at the size a line of text wants.
///
/// One view rather than an `Image` written out wherever a warning is needed:
/// the size and the artwork are then decided in one place, and a sample says
/// only that it is warning about something.
struct WarningMark: ContentView {
    /// How big to draw it. The default matches a heading; a paragraph beside
    /// body text asks for a little more.
    private var side = 14.0

    init() {}

    /// How big to draw it, in device-independent units - it is square, so one
    /// number is the whole answer.
    func size(_ value: Double) -> Self {
        var copy = self
        copy.side = value
        return copy
    }

    var content: Element {
        Image("warning.png")
            .widthRequest(side)
            .heightRequest(side)
            .verticalOptions(.center)
    }
}
