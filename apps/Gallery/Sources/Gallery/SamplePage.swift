// The frame every sample is shown in.

import StateUI

/// One sample: what it is, the live example, and the Swift behind it, in one
/// scroller.
///
/// PUSHED - it arrives as `.sample(id)` on the bound path - so the platform's
/// back button and back gesture work as they do anywhere else, and two samples
/// can be on the stack at once. A sample whose example must hold the page
/// still is shown as tabs instead - see `shown(_:nav:)` and `SampleTabPage`.
struct SamplePage: ContentView {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    let sample: Sample

    let nav: Navigation

    /// The page itself - what it is called, and what is on its bar. A sample
    /// with something of its own for the bar - a search box, buttons, a menu
    /// - writes it into this same session.
    @Environment private var page: PageSession

    /// The page a sample is shown on: this scrolling page, or - for a sample
    /// whose example holds the page still - its tabs, which a window shows as
    /// its own.
    static func shown(_ sample: Sample, nav: Navigation) -> any Page {
        guard !sample.scrolls else { return SamplePage(sample: sample, nav: nav) }

        return TabbedView(sample.tabs) { tab in
            SampleTabPage(sample: sample, tab: tab, nav: nav)
        }
    }

    var content: any View {
        // Dressed as every page of the gallery is. What a sample adds to the
        // bar it writes from its own `.onCreated`, which runs AFTER this one,
        // being further in - so its buttons go before these and its title
        // view, a page having one, replaces the gallery's.
        scrolling.onCreated { page.gallery(sample.title, scene: scene, nav: nav) }
    }

    /// The ordinary page: everything in one scroller, each part under its own
    /// heading - one part, one "EXAMPLE".
    private var scrolling: ScrollView {
        ScrollView {
            VStack {
                summary

                ForEach(sample.parts, id: \.title) { part in
                    VStack {
                        SectionTitle(part.title).warns(sample.warns.contains(part.title))
                        Self.boxed(part.view, notes: part.notes)
                    }
                    .spacing(16)
                }

                // One block usually; a `// -- TITLE --` marker in the code
                // cuts it into sections, each under the words it belongs to.
                // By OFFSET: the code never changes, and two sections may
                // wear one title.
                ForEach(Array(CodeBlock.sections(of: sample.code).enumerated()), id: \.offset) { section in
                    CodeBlock(section.element.code)
                        .title(section.element.title ?? "IN SWIFT")
                        .warns(section.element.title.map(sample.warns.contains) ?? false)
                }
            }
            .spacing(16)
            .padding(24)
        }
    }

    /// The line under the title, saying what the sample is about.
    private var summary: any View {
        Label(sample.summary)
            .fontSize(15)
            .textColor(Palette.subtle)
    }

    /// A part is a view like any other, so it is placed like any other -
    /// inside a Border that marks where it begins.
    ///
    /// A part that FILLS is wrapped in a Grid rather than a VStack: a stack
    /// gives each child the height it asks for, so a list inside one is
    /// measured at all its rows and has nothing left to scroll. A Grid's single
    /// row is a star, which is exactly the bounded height a scroller needs.
    ///
    /// The words go INSIDE the same border, under the example - a star row for
    /// the example and an auto row for the words, so the words keep their
    /// height and what is left is the example's. A held sample usually has none
    /// to place, its words being a tab of their own.
    ///
    /// - Parameter view: the example itself.
    /// - Parameter notes: the words under it, `nil` where there are none or
    ///   where they have a tab.
    /// - Parameter fills: whether the example takes the whole cell.
    static func boxed(_ view: Element, notes: Element? = nil, fills: Bool = false) -> Border {
        Border {
            if fills, let notes {
                Grid {
                    view

                    // A VStack around them for the reason the Grid needs:
                    // `gridRow` is a view's property, and what arrives here is
                    // an Element, which has none.
                    VStack {
                        notes
                    }
                    .gridRow(1)
                }
                .rowDefinitions(.star, .auto)
                .rowSpacing(10)
                .padding(16)
            } else if fills {
                Grid {
                    view
                }
                .padding(16)
            } else {
                VStack {
                    view

                    if let notes {
                        notes
                    }
                }
                .spacing(10)
                .padding(16)
            }
        }
        .stroke(Palette.outline)
        .strokeThickness(1)
        .strokeShape(.roundRectangle(10))
    }
}
