// One row of the menu.

import StateUI

/// A picture, a caption, and somewhere to go.
///
/// An ordinary view with a tap on it - which is the whole of what a sidebar row
/// is. The application knows which row is the chosen one because it holds the
/// answer: `nav.showing(...)`, read while the row is being built, so the look
/// of a chosen row is one ordinary value written on top of its style.
///
/// Tapped rather than pressed, for the reason `Card` is: a button draws its own
/// press, never its surroundings', and every row of this gallery answers a tap
/// this way.
///
/// Shaped like `Card`, and for the same reason: what the row IS goes in the
/// initializer, and everything a caller may leave out is a modifier.
struct MenuRow: View {
    /// What the row says.
    private let title: String

    /// What the row does. It may await, though none of the gallery's do:
    /// choosing a section is an assignment.
    private let action: EventHandler

    /// The picture at the head of it - a file in Resources/Images, in both
    /// themes.
    private var picture: ImageSource = ""

    /// Whether this is the section showing now.
    private var isChosen = false

    /// Which kind of device this is: a touch screen's rows stand taller.
    @Environment(\.device) private var device

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

    /// A view, as everything placed in a stack is.
    var body: some View {
        // Copies for the handler to capture, never `self`: it keeps the two
        // values it needs, not the whole row.
        let action = self.action
        let chosen = self.isChosen
        // A finger takes the taller row a phone's own menus have; a pointer, a
        // desktop sidebar's.
        let touch = device.info.formFactor != .desktop

        return HStack {
            // Hidden rather than absent where a row has no picture: an
            // invisible view is not measured, so the caption starts at the
            // edge instead of after a gap - which is what a row somewhere
            // other than the menu wants. See the Search sample.
            Image(picture)
                .width(20)
                .height(20)
                .isVisible(!picture.isEmpty)
                .verticalAlignment(.center)

            Text(title)
                .style(.menuRowText)
        }
        // The style says what a row is; the line under it says what the CHOSEN
        // one is. A control's own value wins over its style, per property,
        // which is what lets one style serve both.
        .style(.menuRow)
        .spacing(touch ? 14 : 10)
        .padding(horizontal: touch ? 18 : 10, vertical: touch ? 13 : 8)
        .background(chosen ? Palette.selected : .transparent)
        // A row of the menu is a stack with a tap on it, which no platform
        // reads as a control: the picture and the caption are two views, and
        // nothing says they act together. Handle.swift has the rule.
        .accessibilityIdentifier(handle("menu", title))
        .accessibilityLabel(title)
        .onTapped(gate: .ignoreWhileRunning) { try await action() }
    }
}
