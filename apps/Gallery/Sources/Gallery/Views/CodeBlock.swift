// The Swift behind a sample.

import StateUI

/// The code that produced the example above it.
///
/// A block scrolls only horizontally. Its page keeps ownership of vertical
/// scrolling when the pointer is over the listing.
struct CodeBlock: ContentView {
    private let code: String

    private var heading = "IN SWIFT"

    private var warned = false

    /// - Parameter code: The snippet, as a reader would write it.
    init(_ code: String) {
        self.code = code
    }

    /// What the heading above the code says. "IN SWIFT" is the page's
    /// standard; a code SECTION cut off by a `// -- TITLE --` marker names
    /// itself instead, so the code under "EXAMPLE 1" sits under those words.
    ///
    /// EMPTY draws no heading at all - the app's own convention for an absent
    /// string, the one `Card` and `MenuRow` use for an absent icon. A page
    /// that puts the code behind a TAB says "IN SWIFT" there instead, and two
    /// headings saying the same thing is one too many.
    func title(_ value: String) -> Self {
        var copy = self
        copy.heading = value
        return copy
    }

    /// Says the code under this heading shows a TRAP - the same warning the
    /// example itself carries, so the two halves agree wherever the reader
    /// starts. Nothing to show without a heading to put it beside.
    func warns(_ value: Bool) -> Self {
        var copy = self
        copy.warned = value
        return copy
    }

    var content: any View {
        VStack {
            if !heading.isEmpty {
                SectionTitle(heading).warns(warned)
            }

            Border {
                ScrollView {
                    snippet
                }
                .orientation(.horizontal)
                .verticalScrollBarVisibility(.never)
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(8))
        }
        .spacing(8)
    }

    /// How large the code is drawn, in points.
    private let size: Double = 13

    /// The code itself, coloured run by run.
    ///
    /// The label, its spans and the highlight scan are all built inside this
    /// container's closure - which runs when the block is described, and a
    /// block built with the same code, language and heading is carried whole,
    /// so the scan runs once per block rather than once per render.
    private var snippet: any View {
        VStack {
            Label()
                .formattedText {
                    // Identified by OFFSET: two runs may be the same words
                    // in the same colour, and the snippet never changes, so
                    // the offsets never move.
                    ForEach(
                        Array(CodeHighlight.runs(in: code).enumerated()),
                        id: \.offset
                    ) { run in
                        // The size goes on every run rather than on the
                        // Label. A Span carries font properties of its own,
                        // and what an unset one falls back to is the
                        // platform's business - one property per run costs
                        // nothing and leaves nothing to it.
                        TextSpan(run.element.text)
                            .textColor(run.element.colour)
                            .fontSize(size)
                    }
                }
                .padding(14)
        }
    }

    /// The code, cut where a `// -- TITLE --` line names a section.
    ///
    /// The WebView sample's snippet holds both of its examples, and the marker
    /// is what lets each sit under its own heading rather than one block
    /// saying two things. Code with no marker is one section with no title,
    /// and the marker line itself is a comment, so the snippet still compiles
    /// pasted whole.
    static func sections(of code: String) -> [(title: String?, code: String)] {
        var sections: [(title: String?, code: String)] = []
        var current: (title: String?, lines: [Substring]) = (nil, [])

        func close() {
            var lines = current.lines
            while lines.first?.isEmpty == true { lines.removeFirst() }
            while lines.last?.isEmpty == true { lines.removeLast() }

            if !lines.isEmpty {
                sections.append((current.title, lines.joined(separator: "\n")))
            }
        }

        for line in code.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("// -- "), line.hasSuffix(" --"), line.count > 12 {
                close()
                current = (String(line.dropFirst(6).dropLast(3)), [])
            } else {
                current.lines.append(line)
            }
        }

        close()
        return sections
    }
}
