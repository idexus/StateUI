import StateUI

/// A view that wears its own build count in the corner.
///
/// EVERY EXAMPLE IN THIS GALLERY IS ONE - every sample, and every part of a
/// sample that has parts - so a walk through the gallery reads as a
/// measurement: how many times each example has been described, and which piece
/// of state the last description was for. A sample that renders on every finger
/// report says so on its own face, beside one that renders on none.
///
/// `SampleContent` refines it, so a sample is counted by being a sample.
/// `testEveryExampleWearsItsBuildCount` holds the other half: a part view
/// handed to `SamplePart` must be one too, or a held page would be the one kind
/// of example that says nothing.
protocol Counted: ContentView {
    /// The example itself - what a plain view would have called its `content`.
    ///
    /// The name is what makes the count possible without a wrapper: `content`
    /// belongs to this protocol, so the reading is taken inside the example's
    /// own description without anything standing between it and the differ.
    var example: Element { get }
}

extension Counted {
    /// The example, with the count drawn over its top-left corner.
    ///
    /// THE READING HAS TO BE TAKEN INSIDE THIS VIEW'S OWN DESCRIPTION.
    /// `debugInfo()` answers about the build that is running when it is called,
    /// and a `ContentView`'s `content` is exactly what the differ runs inside
    /// that description - so a reading the PAGE took would count the page's
    /// builds, which stand still while a sample's state moves and say nothing.
    ///
    /// A WRAPPING VIEW WAS TRIED AND IS WRONG: standing in front of the example
    /// puts it in the reflection walk's path, so every piece of state the
    /// example holds is named through it and `for offset` becomes
    /// `for example GalleryUI.MapSample…`. Providing `content` here keeps the
    /// example the composed view it always was.
    var content: Element {
        // Before the Grid, deliberately. A container keeps its children's
        // closure on the node and the differ runs it later, so a `debugInfo()`
        // written inside the braces would be asking outside the description it
        // means to report on.
        let reading = BuildCount.of(debugInfo())
        let inner = example

        // A ROW OF ITS OWN, not an overlay. Drawn over the example it sat on
        // top of whatever that example puts in ITS top-left corner - which is
        // usually a caption - and neither could be read.
        //
        // A GRID rather than a stack, because a held page's example must fill
        // the cell it is given: an auto row for the reading and a star row for
        // the example hands the whole of what is left to the example, where a
        // stack would give it its natural height and leave the rest empty.
        return Grid {
            // To the RIGHT, where an example's own captions are not: almost
            // everything here is written left-aligned, so the count reads as a
            // reading about the example rather than as its first line.
            Label(reading)
                .fontSize(12)
                .textColor(Palette.accent)
                .horizontalOptions(.end)
                .horizontalTextAlignment(.end)
                .inputTransparent(true)

            VStack {
                inner
            }
            .gridRow(1)
        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(6)
    }
}

/// The build count on its own, without the view's name.
enum BuildCount {
    /// `debugInfo()` less the name in front of it.
    ///
    /// The name is the one part of that sentence the reader already has: it is
    /// the title of the page they are looking at. What is left is the whole of
    /// what a walk through the gallery is reading - `1 build, first time`,
    /// `41 builds, for volume`.
    ///
    /// - Parameter info: what `debugInfo()` answered.
    /// - Returns: the count and the reason, or the whole sentence where there
    ///   is no name in front to drop.
    static func of(_ info: String) -> String {
        guard let colon = info.firstIndex(of: ":") else { return info }

        var rest = info[info.index(after: colon)...]

        while rest.first == " " {
            rest = rest.dropFirst()
        }

        return rest.isEmpty ? info : String(rest)
    }
}
