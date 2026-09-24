// The Swift behind an example.

import StateUI

/// The code that produced an example, in a box of its own.
///
/// A block scrolls only horizontally. Its page keeps ownership of vertical
/// scrolling when the pointer is over the listing.
struct CodeBlock: ContentView {
    private let code: String

    private var spoken: CodeLanguage = .swift

    /// - Parameter code: The snippet, as a reader would write it.
    init(_ code: String) {
        self.code = code
    }

    /// What the snippet is written in - Swift unless a block says otherwise,
    /// which only a listing beside an example's own code does. Steers the
    /// highlighter's vocabulary and nothing else.
    func language(_ value: CodeLanguage) -> Self {
        var copy = self
        copy.spoken = value
        return copy
    }

    var content: any View {
        ScrollView {
            snippet
        }
        .orientation(.horizontal)
        .verticalScrollBarVisibility(.never)
        .background(Palette.raised)
        .stroke(Palette.outline)
        .strokeWidth(1)
        .shape(.roundedRectangle(8))
        // Code reads left to right in every language, from its first column.
        .layoutDirection(.leftToRight)
    }

    /// How large the code is drawn, in points.
    private let size: Double = 13

    /// The code itself, coloured run by run.
    ///
    /// The label, its spans and the highlight scan are all built inside this
    /// container's closure - which runs when the block is described, and a
    /// block built with the same code is carried whole, so the scan runs once
    /// per block rather than once per render.
    private var snippet: any View {
        VStack {
            Label()
                .spans {
                    // Identified by OFFSET: two runs may be the same words
                    // in the same colour, and the snippet never changes, so
                    // the offsets never move.
                    ForEach(
                        Array(CodeHighlight.runs(in: code, language: spoken).enumerated()),
                        id: \.offset
                    ) { run in
                        // The size goes on every run rather than on the
                        // Label. A span carries font properties of its own,
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
}
