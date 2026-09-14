// What a gallery entry IS.
//
// One control, one idea, one page. Adding a sample means writing a type that
// conforms to SampleContent and naming it in Catalog.swift - nothing else. The
// page around it, the card that links to it and the route that reaches it are
// the same for all of them.

import StateUI

/// What a sample is called and the examples it shows.
///
/// The metadata is STATIC, because it belongs to the sample as a kind rather
/// than to one instance: a card has to say what a sample is called without
/// building the examples behind it.
///
/// A sample of one example IS that example: it conforms to `ExampleContent` as
/// well, and its `examples` are itself. A sample of several lists them, each
/// an `ExampleContent` of its own.
protocol SampleContent {
    /// The route parameter and the row's identity. Unique across the catalog.
    static var id: String { get }

    /// The heading, and the card's title.
    static var title: String { get }

    /// One line, shown on the card and under the heading.
    static var summary: String { get }

    /// Whether the page may put the examples in a scroller. Yes unless a
    /// sample says otherwise.
    ///
    /// A gesture sample says no. A scroller claims a drag before the view
    /// under it hears about it, so a pan inside one reports nothing vertically
    /// and a swipe up or down never arrives at all. The page then holds each
    /// example still on a tab of its own, with the words and the code on one
    /// more.
    static var scrolls: Bool { get }

    /// Which kinds of device LIST this sample. Everywhere unless a sample says
    /// otherwise; a sample about desktop chrome says `[.desktop]`.
    ///
    /// What it steers is the listing - the group's page, the home page's
    /// count, the "Surprise me" pick. The ROUTE still reaches the page on any
    /// device, deliberately: a link followed is better answered by the page
    /// saying what is missing than by a dead end.
    static var formFactors: Set<FormFactor> { get }

    /// Whether an example is given the WINDOW's height rather than its own -
    /// true for an example that scrolls itself, such as a `ScrollView`,
    /// `GalleryView`, or WebView.
    ///
    /// Such an example needs a bounded height, and stating one in points is the
    /// wrong way to bound it: a list of `.height(240)` shows the same
    /// four rows on a phone and on a 27-inch screen, with the rest of the page
    /// empty under it. Filling the cell instead makes the example as tall as
    /// there is room for, and the thing inside it already knows how to scroll.
    ///
    /// Only ever true beside `scrolls == false`: an example inside the page's
    /// own scroller has no bounded height to fill.
    static var fills: Bool { get }

    /// The examples, in the order the page shows them: "Example" where there
    /// is one, "Example 1", "Example 2" and on where there are several.
    var examples: [Example] { get }
}

extension SampleContent {
    static var scrolls: Bool { true }

    /// An example as tall as it needs to be, which is what almost every sample
    /// is - only the ones that scroll themselves ask for the window's height.
    static var fills: Bool { false }

    /// Listed on every kind of device, which is what almost every sample is.
    static var formFactors: Set<FormFactor> { [.phone, .tablet, .desktop, .tv, .watch] }
}

extension SampleContent where Self: ExampleContent {
    /// The sample itself, its one example.
    var examples: [Example] { [Example(self)] }
}

/// One example: a piece of interface, the words about it, and the Swift that
/// wrote it.
///
/// A `ContentView`, because that is what a piece of interface is in this
/// library - so an example is written the way an application writes one, and
/// a build reading it takes sits where the example means it to and is shown in
/// the same place in `code`. Its `@State` is its own, carried by the catalog
/// the gallery keeps.
///
/// The example says as little as it can: its controls, what they report, and
/// at most one line saying what to try. Everything else is `notes`.
protocol ExampleContent: ContentView {
    /// The Swift that produced the example: its own code with the decoration
    /// taken out, as a reader would write it.
    static var code: String { get }

    /// The words about the example - what it shows and why - or `nil` where
    /// it says everything itself.
    ///
    /// A live READING - a tally, a count, "3 ticked" - is not a note and
    /// belongs in the example: it is what the example is doing. The notes are
    /// built once, with the catalog, so they are words that never change.
    ///
    /// An `Element` and not a string, so the words are written the way every
    /// other view here is. Required with no default, so a `notes` of any other
    /// type is a compile error rather than a property nothing reads.
    var notes: Element? { get }
}

/// One example as its page shows it: the view, the words about it, and its
/// Swift.
struct Example {
    /// The example itself, as a value whose content builds when the page does.
    let view: Element

    /// The words about it, where it has any.
    let notes: Element?

    /// The Swift that wrote it.
    let code: String

    init<Content: ExampleContent>(_ content: Content) {
        view = content
        notes = content.notes
        code = Content.code
    }
}

/// A sample as the gallery holds it: the metadata read off the type, and the
/// examples as values that have not been built yet.
///
/// The type's metadata is copied out rather than the sample kept, because an
/// existential of a protocol with static requirements cannot stand in for
/// itself - and once the metadata has been copied there is nothing left to ask
/// the type for.
struct Sample {
    let id: String
    let title: String
    let summary: String
    let scrolls: Bool
    let formFactors: Set<FormFactor>

    /// Whether an example is given the window's height rather than its own.
    let fills: Bool

    /// The examples, usually one. Stored as values: an example is a
    /// ContentView, so what is kept here is a placeholder whose content builds
    /// when the page does - and whose `@State` lives as long as the gallery
    /// that keeps this catalog.
    let examples: [Example]

    /// Whether a device of `formFactor` lists this sample. An UNKNOWN formFactor - a
    /// headless test, a host that could not say - lists everything: hiding is
    /// a courtesy to the reader, and a test wants to see it all.
    func isShown(on formFactor: FormFactor) -> Bool {
        formFactor == .unknown || formFactors.contains(formFactor)
    }

    /// What the page calls example `index`: "Example" where it is the only one,
    /// "Example 2" among several. Its words and its code are always "Notes"
    /// and "In Swift"; among several examples the example's name heads them.
    func name(ofExample index: Int) -> String {
        examples.count == 1 ? "Example" : "Example \(index + 1)"
    }

    init<Content: SampleContent>(_ content: Content) {
        id = Content.id
        title = Content.title
        summary = Content.summary
        scrolls = Content.scrolls
        formFactors = Content.formFactors
        fills = Content.fills
        examples = content.examples
    }
}

/// A sample IS its id: the catalog makes every sample once, so two with one id
/// are the same sample - which is what lets the page showing one be carried
/// when the window builds for a move somewhere else on the stack.
extension Sample: Equatable {
    static func == (a: Sample, b: Sample) -> Bool { a.id == b.id }
}
