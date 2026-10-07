// The frame every sample is shown in.

import StateUI

/// One sample on one scroller: the line saying what it is about, then each
/// example with its notes and its Swift under it.
///
/// PUSHED - it arrives as `.sample(id)` on the bound path - so the platform's
/// back button and back gesture work as they do anywhere else, and two samples
/// can be on the stack at once. A sample whose examples must hold the page
/// still is shown as tabs instead - see `shown(_:nav:bar:)` and `SampleTabPage`.
struct SamplePage: View {
    /// The gallery this page is in - its scene.
    @Environment(\.scene) var scene

    let sample: Sample

    let nav: Navigation

    /// The page a sample is shown on: this scrolling page, or - for a sample
    /// whose examples hold the page still - its tabs, which a window shows as
    /// its own, on a bar painted `bar` as the stack they are pushed onto is; nil
    /// for the platform's own.
    /// The tabs carry the sample's name, which names the window while they are
    /// the stack's last place; their pages name the tabs alone.
    @ViewBuilder
    static func shown(_ sample: Sample, nav: Navigation, bar: Color?) -> some View {
        if sample.scrolls {
            SamplePage(sample: sample, nav: nav)
        } else {
            TabView(sample.tabs) { tab in
                SampleTabPage(sample: sample, tab: tab, nav: nav)
            }
            .title(sample.title)
            .paintedBars(bar)
        }
    }

    var body: some View {
        // Dressed as every page of the gallery is. What a sample adds to the
        // bar - its buttons, its title view - it declares on its own views.
        scrolling.galleryPage(sample.title)
    }

    /// Everything in one scroller: the summary, then each example with its
    /// notes and its Swift. The notes sit in no scroller of their own and a
    /// listing scrolls only across, so the page's scroller is the one thing
    /// that moves down.
    private var scrolling: ScrollView {
        ScrollView {
            VStack {
                Text(sample.summary)
                    .fontSize(15)
                    .textColor(Palette.subtle)

                // By OFFSET: the examples never change.
                ForEach(Array(sample.examples.enumerated()), id: \.offset) { item in
                    sections(of: item.element, at: item.offset)
                }
            }
            .spacing(24)
            .padding(24)
        }
    }

    /// One example as this page shows it: "Example", "Notes" and "In Swift",
    /// each over what it names. Among several examples, the example's name -
    /// "Example 2" - heads its whole group instead.
    private func sections(of example: Example, at index: Int) -> some View {
        let name = sample.name(ofExample: index)
        let box = Self.boxed(example.view)

        return VStack {
            if sample.examples.count > 1 {
                VStack {
                    ExampleTitle(name)
                    box
                }
                .spacing(8)
            } else {
                Self.section(name, box)
            }

            if let notes = example.notes {
                Self.section("Notes", ModifiedContent(node: notes.node))
            }

            Self.section(example.codeHeading, CodeBlock(example.code))

            // The far side of the example, where it has one: a section per
            // language its host's half is written in.
            example.hostCode.listings.map { listing -> any View in
                Self.section(
                    example.hostCode.heading(of: listing), CodeBlock(listing.code).language(listing.language))
            }
        }
        .spacing(16)
    }

    /// A heading over what it names.
    ///
    /// - Parameter heading: what the section is called.
    /// - Parameter content: what it holds.
    static func section<Content: View>(_ heading: String, _ content: Content) -> some View {
        VStack {
            SectionTitle(heading)
            content
        }
        .spacing(8)
    }

    /// An example is a view like any other, so it is placed like any other -
    /// inside a card that marks where it begins.
    ///
    /// An example that FILLS is wrapped in a Grid rather than a VStack: a stack
    /// gives each child the height it asks for, so a list inside one is
    /// measured at all its rows and has nothing left to scroll. A Grid's single
    /// row is a star, which is exactly the bounded height a scroller needs.
    ///
    /// - Parameter view: the example itself.
    /// - Parameter fills: whether the example takes the whole cell.
    static func boxed<Content: View>(_ view: Content, fills: Bool = false) -> ZStack {
        ZStack {
            if fills {
                Grid {
                    view
                }
                .padding(16)
            } else {
                VStack {
                    view
                }
                .padding(16)
            }
        }
        .style("Card")
        .stroke(Palette.outline)
        .lineWidth(1)
        .shape(.roundedRectangle(10))
    }
}
