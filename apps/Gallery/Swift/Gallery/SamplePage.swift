// The frame every sample is shown in.

import StateUI

/// One sample: what it is, the live example, and the Swift behind it.
///
/// PUSHED - it arrives as `.sample(id)` on the bound path - so the platform's
/// back button and back gesture work as they do anywhere else, and two samples
/// can be on the stack at once.
struct SamplePage: GalleryPage {
    let sample: Sample

    let nav: Navigation

    var title: String? { sample.title }

    /// A sample about searching puts its box on the navigation BAR, in place of
    /// the title. MAUI hangs a title view off the PAGE - `NavigationPage.
    /// TitleView` - so it can only be asked for here.
    ///
    /// The sample's own if it has one - the search box is a title view, and a
    /// page cannot have two - and otherwise the title in the gallery's own
    /// hand, which is what every other page shows.
    var navigationPageTitleView: Element? {
        sample.navigationPageTitleView() ?? MenuTitle(title ?? "")
    }

    /// And a sample about the keyboard asks the page to give it back on a tap,
    /// for the same reason: it is the PAGE that MAUI gives the property to.
    var hideSoftInputOnTapped: Bool? { sample.hideSoftInputOnTapped }

    /// The sample's own, plus the way home. Added rather than substituted: a
    /// sample that declares toolbar items is showing what they are for.
    var toolbarItems: [ToolbarItem] { sample.toolbarItems() + [.home(nav)] }

    var menuBarItems: [MenuBarItem] { sample.menuBarItems() }

    /// Which tab is showing, as an index into `tabs` - the parts first, then
    /// NOTES where the phone took them, then the code. Only the held layout
    /// has tabs; the scrolling one shows everything at once and never reads
    /// this.
    ///
    /// It is `@State`, so it survives the page being rebuilt - a render asked
    /// for by the example itself must not throw the reader back to it.
    @State private var showing = 0

    /// A phone is what moves the words off the example. See `notesTab`.
    @Environment private var device: DeviceInfo

    var content: Element {
        sample.scrolls ? scrolling : held
    }

    /// The ordinary page: everything in one scroller, each part under its own
    /// heading - one part, one "EXAMPLE", which is the page as it always was.
    private var scrolling: Element {
        ScrollView {
            VStack {
                summary

                ForEach(sample.parts, id: \.title) { part in
                    VStack {
                        SectionTitle(part.title).warns(sample.warns.contains(part.title))
                        boxed(part.view, notes: part.notes)
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

                // The C# half, where a sample has one - the interop group's
                // registrations and controls.
                if !sample.codeCSharp.isEmpty {
                    CodeBlock(sample.codeCSharp).language(.csharp).title("IN C#")
                }
            }
            .spacing(16)
            .padding(24)
        }
    }

    /// A page whose example is not in a scroller, with TABS - one per part,
    /// and IN SWIFT after them.
    ///
    /// A gesture sample asks for this. A ScrollView claims a drag before the
    /// view under it hears about it, so an example inside one loses every
    /// gesture that looks like scrolling to the platform - which on a phone is
    /// most of them.
    ///
    /// So the parts and the code take TURNS in one cell rather than sharing
    /// the height. Splitting a phone screen between them left each with too
    /// little to be worth looking at, and the example is the half that cannot
    /// be given less: it is a gesture, and a gesture needs somewhere to happen.
    ///
    /// ALL of them stay in the tree, hidden rather than dropped, because
    /// leaving the tree is what ends a view's state - and what a gesture
    /// sample has to show IS its state, as a WebView's is its history. Reading
    /// the code and coming back must not reset either.
    ///
    /// Only the code half is in a scroller. The example is the one that must
    /// not be, and the tab is what lets it not be.
    private var held: Element {
        Grid {
            VStack {
                summary
                Tabs(tabs).selection($showing)
            }
            .spacing(16)
            .gridRow(0)

            ForEach(Array(sample.parts.enumerated()), id: \.offset) { part in
                // The words stay under the example unless a phone took them -
                // and where it did, the example gets the whole cell.
                boxed(part.element.view,
                      notes: notesTab == nil ? part.element.notes : nil,
                      fills: sample.fills)
                    // An example that scrolls itself takes the whole cell; one
                    // that does not stays its own height at the top of it,
                    // rather than being stretched down the screen.
                    .verticalOptions(sample.fills ? .fill : .start)
                    .isVisible(showing == part.offset)
                    .gridRow(1)
            }

            if let notesTab {
                ScrollView {
                    VStack {
                        ForEach(Array(sample.parts.enumerated()), id: \.offset) { part in
                            VStack {
                                // Whose words these are, where a sample has two
                                // examples; a lone example needs no heading,
                                // the tab above already says NOTES.
                                if sample.parts.count > 1 {
                                    SectionTitle(part.element.title)
                                        .warns(sample.warns.contains(part.element.title))
                                }

                                if let notes = part.element.notes {
                                    notes
                                }
                            }
                            .spacing(16)
                        }
                    }
                    .spacing(24)
                }
                .orientation(.vertical)
                .isVisible(showing == notesTab)
                .gridRow(1)
            }

            ScrollView {
                VStack {
                    // The tab above already says IN SWIFT, so a lone block
                    // goes untitled - while a section a marker named says its
                    // own words, EXAMPLE 1 over the code of example 1.
                    ForEach(Array(CodeBlock.sections(of: sample.code).enumerated()), id: \.offset) { section in
                        // No heading where the marker named none: the TAB
                        // above already says IN SWIFT.
                        CodeBlock(section.element.code)
                            .title(section.element.title ?? "")
                            .warns(section.element.title.map(sample.warns.contains) ?? false)
                    }
                }
                .spacing(16)
            }
            .orientation(.vertical)
            .isVisible(showing == swiftTab)
            .gridRow(1)

            if !sample.codeCSharp.isEmpty {
                ScrollView {
                    CodeBlock(sample.codeCSharp).language(.csharp).title("")
                }
                .orientation(.vertical)
                .isVisible(showing == swiftTab + 1)
                .gridRow(1)
            }
        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(16)
        .padding(24)
    }

    /// The tabs across the top of a held page: one per part, NOTES where a
    /// phone took the words off the example, then the code.
    private var tabs: [String] {
        sample.parts.map(\.title)
            + (notesTab == nil ? [] : ["NOTES"])
            + ["IN SWIFT"]
            + (sample.codeCSharp.isEmpty ? [] : ["IN C#"])
    }

    /// Where a PHONE puts the words - a tab of their own, after the examples -
    /// and `nil` on anything bigger, which keeps them under the example.
    ///
    /// A held page cannot scroll, so the words and the example share one
    /// screen: measured on an iPhone SE, `Incremental loading` gave the list
    /// three rows and the words the rest. A desktop has room for both and
    /// reads better with the explanation where the eye already is.
    private var notesTab: Int? {
        device.idiom == .phone && sample.parts.contains { $0.notes != nil }
            ? sample.parts.count
            : nil
    }

    /// The code tab, one past the parts - and past NOTES where there is one.
    private var swiftTab: Int { sample.parts.count + (notesTab == nil ? 0 : 1) }

    /// The line under the title, saying what the sample is about.
    private var summary: Element {
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
    /// height and what is left is the example's.
    ///
    /// - Parameter notes: the words under the example, `nil` where a part has
    ///   none - or where a phone moved them to a tab of their own.
    private func boxed(_ view: Element, notes: Element? = nil, fills: Bool = false) -> Border {
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
