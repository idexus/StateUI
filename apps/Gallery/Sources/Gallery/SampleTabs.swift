// A sample that holds its page still, shown as tabs.

import StateUI

/// One tab of a sample whose examples hold the page still.
enum SampleTab: Hashable {
    /// One of its examples, by its place among them.
    case example(Int)

    /// Its code: each example's notes and Swift, in turn.
    case code
}

extension Sample {
    /// The tabs of a page that holds still: each example, then the code.
    var tabs: [SampleTab] {
        examples.indices.map(SampleTab.example) + [.code]
    }

    /// What a tab is called: "Example", or "Example 1" and on, then "In Code".
    func caption(of tab: SampleTab) -> String {
        switch tab {
        case .example(let index):
            return name(ofExample: index)
        case .code:
            return "In Code"
        }
    }
}

/// One tab of a sample whose examples hold the page still: the line saying
/// what the sample is about, over one of its examples or over its code.
///
/// A gesture sample asks for this. A scroller claims a drag before the view
/// under it hears about it, so an example inside one loses every gesture that
/// looks like scrolling to the platform. The page is held to the window's
/// height instead, and each example takes a tab of its own. The code tab is
/// the one that scrolls: each example's notes and then its Swift, in turn -
/// the notes in no scroller of their own and each listing scrolling only
/// across, so nothing competes with the tab's own scroller.
///
/// Every tab stays in the tree while the sample is shown, so reading the code
/// and coming back keeps the example's state - what a gesture sample has to
/// show IS its state.
struct SampleTabPage: ContentView {
    /// The gallery this page is in - the scene its inspector button opens.
    @Environment var scene: SceneSession

    /// The page itself - what it is called, and what is on its bar.
    @Environment private var page: PageSession

    let sample: Sample

    let tab: SampleTab

    let nav: Navigation

    var content: any View {
        FrameReader { frame in
            held
                .height(frame.height)
                .width(frame.width)
                .verticalAlignment(.start)
                .horizontalAlignment(.start)
        }
        // Dressed as every page of the gallery is, and named for its tab: the
        // tab's caption, and the window's title while the tab is chosen. What
        // a sample adds to the bar it writes from its own `.onCreated`, which
        // runs after this one, being further in.
        .onCreated { page.gallery(sample.caption(of: tab), scene: scene, nav: nav) }
    }

    /// The line under the title over what the tab shows, in one cell that
    /// fills the rest of the page.
    private var held: Grid {
        Grid {
            Label(sample.summary)
                .fontSize(15)
                .textColor(Palette.subtle)

            if case .example(let index) = tab {
                // An example that scrolls itself takes the whole cell; one
                // that does not keeps its own height at the top.
                SamplePage.boxed(sample.examples[index].view, fills: sample.fills)
                    .verticalAlignment(sample.fills ? .fill : .start)
                    .gridRow(1)
            } else {
                ScrollView {
                    VStack {
                        ForEach(Array(sample.examples.enumerated()), id: \.offset) { item in
                            explanation(of: item.element, at: item.offset)
                        }
                    }
                    .spacing(24)
                }
                .orientation(.vertical)
                .gridRow(1)
            }
        }
        .rows(.auto, .fill)
        .rowSpacing(16)
        .padding(24)
    }

    /// One example's notes and Swift, under "Notes" and "In Swift" - and,
    /// among several examples, under the example's name as well.
    private func explanation(of example: Example, at index: Int) -> any View {
        VStack {
            if sample.examples.count > 1 {
                ExampleTitle(sample.name(ofExample: index))
            }

            if let notes = example.notes {
                SamplePage.section("Notes", notes)
            }

            SamplePage.section("In Swift", CodeBlock(example.code))
        }
        .spacing(16)
    }
}
