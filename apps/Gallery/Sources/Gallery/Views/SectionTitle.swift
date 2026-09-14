// The heading above a section.

import StateUI

/// The heading over a section of a page - "Example", "Notes", "In Swift".
///
/// What it says is the initializer's one argument.
struct SectionTitle: ContentView {
    private let text: String

    /// - Parameter text: What the heading says.
    init(_ text: String) {
        self.text = text
    }

    var content: any View {
        Label(text)
            // A HEADING IS WHAT THIS SAYS IT IS, not what it is drawn like:
            // a reader moving through a long sample page by its headings
            // lands on these, and on nothing that merely looks bold.
            .accessibilityHeadingLevel(.level2)
            .fontSize(13)
            .fontAttributes(.bold)
            .textColor(Palette.subtle)
            .verticalAlignment(.center)
    }
}

/// The heading over one example among several - "Example 2" - and over the
/// notes and code that belong to it: larger than a section's heading and in
/// the accent colour, so each example's group reads as one.
struct ExampleTitle: ContentView {
    private let text: String

    /// - Parameter text: What the heading says.
    init(_ text: String) {
        self.text = text
    }

    var content: any View {
        Label(text)
            .accessibilityHeadingLevel(.level2)
            .fontSize(17)
            .fontAttributes(.bold)
            .textColor(Palette.accent)
            .verticalAlignment(.center)
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

    var content: any View {
        Image("warning.png")
            .width(side)
            .height(side)
            .verticalAlignment(.center)
    }
}
