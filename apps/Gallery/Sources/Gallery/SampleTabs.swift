// A sample that holds its page still, shown as tabs.

import StateUI

/// One tab of a sample whose example holds the page still.
enum SampleTab: Hashable {
    /// One of its examples, by its place among them.
    case part(Int)

    /// Its words, where they are kept apart from the examples.
    case notes

    /// Its Swift.
    case swift

    /// Its C#, where it has any.
    case csharp
}

extension Sample {
    /// The tabs of a page that holds still: each example, the words where a
    /// part has words the sample did not keep under it, the Swift, and the C#
    /// where there is any.
    var tabs: [SampleTab] {
        parts.indices.map(SampleTab.part)
            + (notesHaveTab ? [.notes] : [])
            + [.swift]
            + (codeCSharp.isEmpty ? [] : [.csharp])
    }

    /// Whether the words take a tab of their own.
    ///
    /// NOTHING ON A HELD PAGE SCROLLS but the words and the code, so words that
    /// do not fit beside the example take a turn like it - unless the sample
    /// says `notesUnder`, which keeps them under the example, where the eye
    /// already is.
    var notesHaveTab: Bool {
        !notesUnder && parts.contains { $0.notes != nil }
    }

    /// What a tab is called, in the words a tab takes: each word capitalized.
    func caption(of tab: SampleTab) -> String {
        switch tab {
        case .part(let index):
            return parts[index].title
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: " ")
        case .notes:
            return "Notes"
        case .swift:
            return "In Swift"
        case .csharp:
            return "In C#"
        }
    }
}

/// One tab of a sample whose example holds the page still: the line saying
/// what the sample is about, over one of its examples, its words or its code.
///
/// A gesture sample asks for this. A ScrollView claims a drag before the view
/// under it hears about it, so an example inside one loses every gesture that
/// looks like scrolling to the platform. The page is held to the window's
/// height instead, and the example, the words and the code take turns as the
/// window's tabs rather than sharing the height. The words and the code are
/// each in a scroller of their own, which lets them be long; the example is
/// the one that must not be in one.
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
                .heightRequest(frame.height)
                .widthRequest(frame.width)
                .verticalOptions(.start)
                .horizontalOptions(.start)
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

            if case .part(let index) = tab {
                // The words go under the example unless they have a tab of
                // their own; an example that scrolls itself takes the whole
                // cell, one that does not keeps its own height at the top.
                SamplePage.boxed(
                    sample.parts[index].view,
                    notes: sample.notesHaveTab ? nil : sample.parts[index].notes,
                    fills: sample.fills)
                    .verticalOptions(sample.fills ? .fill : .start)
                    .gridRow(1)
            } else if tab == .notes {
                ScrollView {
                    VStack {
                        ForEach(Array(sample.parts.enumerated()), id: \.offset) { part in
                            VStack {
                                // Whose words these are, where a sample has two
                                // examples; a lone example needs no heading.
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
                .gridRow(1)
            } else if tab == .swift {
                ScrollView {
                    VStack {
                        // The tab already says In Swift, so a lone block goes
                        // untitled - while a section a marker named says its own
                        // words, EXAMPLE 1 over the code of example 1.
                        ForEach(Array(CodeBlock.sections(of: sample.code).enumerated()), id: \.offset) { section in
                            CodeBlock(section.element.code)
                                .title(section.element.title ?? "")
                                .warns(section.element.title.map(sample.warns.contains) ?? false)
                        }
                    }
                    .spacing(16)
                }
                .orientation(.vertical)
                .gridRow(1)
            } else {
                ScrollView {
                    CodeBlock(sample.codeCSharp).language(.csharp).title("")
                }
                .orientation(.vertical)
                .gridRow(1)
            }
        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(16)
        .padding(24)
    }
}
