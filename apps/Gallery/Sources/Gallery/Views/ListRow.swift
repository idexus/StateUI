// One row of a list that leads somewhere.

import StateUI

/// A row of a grouped list: what it leads to, the line under it, and a
/// chevron saying it goes somewhere.
///
/// A ROW IS A ZSTACK WITH A TAP ON IT, standing with its neighbors in one
/// rounded group - the "RowGroup" style - with a hairline between each row and
/// the one before it.
///
/// It is shaped the way every control in the library is, and that shape is the
/// rule for a composed view of your own: WHAT IT IS goes in the initializer -
/// with no default, so leaving it out is not a thing that can happen - and
/// everything a caller may leave out is a MODIFIER returning `Self`, one copy
/// and one assignment, as this row's `icon` modifier is written.
///
/// Its own modifiers are written FIRST, before the ones every view has:
/// `.margin` and friends give back a `ModifiedContent`, which is a view and no
/// longer a `ListRow`.
struct ListRow: View {
    private let title: String
    private let summary: String
    private let action: EventHandler

    /// A file in Resources/Images, or empty for no icon.
    private var picture: ImageSource = ""

    /// Whether a hairline divides the row from the one before it.
    private var isSeparated = false

    /// - Parameters:
    ///   - title: What the row is called.
    ///   - summary: The line under it.
    ///   - action: Run when the row is tapped. May await - tapping a row
    ///     navigates, and where it goes is what a row IS; a tap while it runs
    ///     is let go.
    init(_ title: String, summary: String, action: @escaping EventHandler) {
        self.title = title
        self.summary = summary
        self.action = action
    }

    /// The picture at the head of the row - a file in Resources/Images. A
    /// row that names none draws none, and the words start at the edge.
    func icon(_ value: ImageSource) -> Self {
        var copy = self
        copy.picture = value
        return copy
    }

    /// Divides the row from the one before it with a hairline.
    func separated(_ value: Bool) -> Self {
        var copy = self
        copy.isSeparated = value
        return copy
    }

    var body: some View {
        // A copy for the handler to capture: the local keeps `self` out of
        // the closure. ConcurrencyTests pins this shape on the library's
        // executor.
        let action = self.action

        return ZStack {
            Rectangle()
                .fill(Palette.outline)
                .height(1)
                .margin(start: 16, top: 0, end: 0, bottom: 0)
                .verticalAlignment(.start)
                .isVisible(isSeparated)

            Grid {
                Image(picture)
                    .width(24)
                    .height(24)
                    .isVisible(!picture.isEmpty)
                    .verticalAlignment(.center)

                VStack {
                    // The name in the platform's body and the words' own
                    // color, the line under it a caption: each platform's
                    // own steps, so the name stands as large as the page's
                    // words and clear of the line under it.
                    Text(title)
                        .textStyle(.body)
                        .textColor(Palette.text)

                    Text(summary)
                        .textStyle(.caption)
                        .textColor(Palette.subtle)
                        .maximumLines(2)
                }
                .gridColumn(1)
                .spacing(2)
                .horizontalAlignment(.fill)
                .verticalAlignment(.center)

                Text("›")
                    .gridColumn(2)
                    .fontSize(20)
                    .textColor(Palette.disabled)
                    .verticalAlignment(.center)
            }
            .columnSpacing(12)
            // The TEXT is the star column: a star column is given what the
            // others left, and a Text given a width wraps to it.
            .columns(.auto, .fill, .auto)
            .padding(horizontal: 16, vertical: 11)
        }
        .style(.listRow)
        // A ROW IS A ZSTACK WITH A TAP ON IT, which no platform reads as a
        // control: so the row says what it is and where it goes, and the
        // handle is worked out from the title - see Handle.swift.
        .accessibilityIdentifier(handle("row", title))
        .accessibilityLabel(title)
        .accessibilityHint(summary)
        // Pressed as a button: lit by its style while the press stands over
        // it, tapped where it lets go over it.
        .onTapped(.ignoreWhileRunning) { try await action() }
    }
}
