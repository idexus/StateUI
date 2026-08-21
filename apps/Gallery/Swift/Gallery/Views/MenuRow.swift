// One row of the menu.

import StateUI

/// A picture, a caption, and somewhere to go.
///
/// An ordinary view with a tap on it - which is the whole of what a flyout row
/// is. The application knows which row is the chosen one because it holds the
/// answer: `nav.showing(...)`, read while the row is being built, so the look
/// of a chosen row is two ordinary values written on top of its style.
///
/// Tapped rather than pressed, for the reason `Card` is: MAUI draws nothing when
/// a Button's surroundings are what should look pressed, and every row of this
/// gallery already answers a tap this way.
///
/// Shaped like `Card`, and for the same reason: what the row IS goes in the
/// initializer, and everything a caller may leave out is a modifier.
struct MenuRow: Element {
    /// What the row says.
    private let title: String

    /// What the row does. It may await, though none of the gallery's do any
    /// more: choosing a section is an assignment now.
    private let action: EventHandler

    /// The picture at the head of it - a file in Resources/Images, in both
    /// themes.
    private var picture: ImageSource = ""

    /// Whether this is the section showing now.
    private var isChosen = false

    /// - Parameters:
    ///   - title: What the row says.
    ///   - action: What tapping it does.
    init(_ title: String, action: @escaping EventHandler) {
        self.title = title
        self.action = action
    }

    /// The picture at the head of the row, in both themes. A row that names
    /// none leaves the space out - see the note in the body.
    func icon(_ value: ImageSource) -> Self {
        var copy = self
        copy.picture = value
        return copy
    }

    /// Says this is the section showing now, which is what makes it read as
    /// chosen. The row that performs an ACT - "Surprise me" - never is.
    func chosen(_ value: Bool) -> Self {
        var copy = self
        copy.isChosen = value
        return copy
    }

    /// `Element` rather than `ContentView`: this row is only ever placed inside
    /// a stack and wears no modifier of its own, and an `Element` requires
    /// nothing but `body`.
    ///
    /// Which is also what it OFFERS - a plain `Element` wears no modifiers at
    /// all, `.margin`, `.onLoaded` and `.isVisible` among them, and the compiler
    /// names the missing modifier rather than the base protocol. A composed view
    /// that must wear any of them is a `ContentView`.
    var body: Node {
        // Copies for the handler to capture, never `self` - see the note in
        // Card.swift: a closure written in a body getter that captures the view
        // is moved off this library's executor by the compiler, and the press
        // then waits for the next event to arrive.
        let action = self.action
        let chosen = self.isChosen

        return HStack {
            // Hidden rather than absent where a row has no picture: an
            // invisible view is not measured, so the caption starts at the
            // edge instead of after a gap - which is what a row somewhere
            // other than the menu wants. See the Search sample.
            Image(picture)
                .widthRequest(20)
                .heightRequest(20)
                .isVisible(!picture.isEmpty)
                .verticalOptions(.center)

            // The style says what a row's caption is; the two lines under it
            // say what the CHOSEN one is. A control's own value wins over its
            // style, per property, which is what lets one style serve both.
            Label(title)
                .style("MenuRowText")
                .textColor(chosen ? Palette.accent : Palette.subtle)
                .fontAttributes(chosen ? .bold : .none)
        }
        .style("MenuRow")
        .backgroundColor(chosen ? Palette.selected : .transparent)
        .onTapped { try await action() }
        .body
    }
}
