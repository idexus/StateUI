// One row of a list that leads somewhere.

import StateUI

/// A row of a grouped list: what it leads to, the line under it, and a
/// chevron saying it goes somewhere.
///
/// A ROW IS A GRID WITH A TAP ON IT, standing with its neighbours in one
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

    /// How lit the row is - the press, said back. DRIVEN: the host carries it
    /// on its own frames and no render describes it, so a press costs the
    /// arithmetic and nothing else.
    @State private var lit = 0.0

    /// - Parameters:
    ///   - title: What the row is called.
    ///   - summary: The line under it.
    ///   - action: Run when the row is tapped. May await - tapping a row
    ///     navigates, and where it goes is what a row IS.
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

    /// `View`, not `Element`: the press is a piece of `@State`, and state on a
    /// view needs the placeholder a composed view puts in the tree.
    var body: some View {
        // Copies for the handler to capture: the locals keep `self` out of
        // the closure. ConcurrencyTests pins this shape on the library's
        // executor.
        let lit = $lit
        let action = self.action

        return ZStack {
            ColorBox(Palette.selected)
                .opacity(lit)

            ColorBox(Palette.outline)
                .height(1)
                .margin(left: 16, top: 0, right: 0, bottom: 0)
                .verticalAlignment(.start)
                .isVisible(isSeparated)

            Grid {
                Image(picture)
                    .width(24)
                    .height(24)
                    .isVisible(!picture.isEmpty)
                    .verticalAlignment(.center)

                VStack {
                    Text(title)

                    Text(summary)
                        .fontSize(13)
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
        .style("ListRow")
        // A ROW IS A ZSTACK WITH A TAP ON IT, which no platform reads as a
        // control: so the row says what it is and where it goes, and the
        // handle is worked out from the title - see Handle.swift.
        .accessibilityIdentifier(handle("row", title))
        .accessibilityLabel(title)
        .accessibilityHint(summary)
        // The press, said back as a platform's list says it: the row lights
        // up and goes out again. It lights before the action starts - a
        // page's build holds the UI thread, which eats the frames beside it -
        // and goes out while the navigation runs.
        .onTapped {
            try await lit.journey.move(to: 1, .eased(60, .cubicOut))
            async let dark: Bool = lit.journey.move(to: 0, .eased(250, .cubicOut))
            try await action()
            _ = try await dark
        }
    }
}
