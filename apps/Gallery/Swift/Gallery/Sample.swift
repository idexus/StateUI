// What a gallery entry IS.
//
// One control, one idea, one page. Adding a sample means writing a type that
// conforms to SampleContent and naming it in Catalog.swift - nothing else. The
// page around it, the card that links to it and the route that reaches it are
// the same for all of them.

import StateUI

/// A sample's own half: the example, and what to call it.
///
/// A `ContentView`, because that is what a piece of interface is in this
/// library - so a sample's `content` is written the way an application writes
/// one, and a reading it takes (`DebugInfoLabel()`) sits where the sample
/// means it to and is shown in the same place in `code`. The metadata on top
/// is STATIC, because it belongs to the sample as a kind rather than to one
/// instance: a card has to say what a sample is called without building the
/// example behind it.
protocol SampleContent: ContentView {
    /// The route parameter and the row's identity. Unique across the catalog.
    static var id: String { get }

    /// The heading, and the card's title. The MAUI type where there is one.
    static var title: String { get }

    /// One line, shown on the card and under the heading.
    static var summary: String { get }

    /// The Swift that produced the example, as a reader would write it.
    static var code: String { get }

    /// The C# behind the example, when there is any - what the interop
    /// samples show under IN C#: the registration in MauiProgram, the control
    /// class beside it. Empty for a sample with no C# half, which is most of
    /// them, and the page then draws no section.
    static var codeCSharp: String { get }

    /// Whether the page may put the example in a scroller. Yes unless a sample
    /// says otherwise.
    ///
    /// A gesture sample says no. A ScrollView claims a drag before the view
    /// under it hears about it, so a pan inside one reports nothing vertically
    /// and a swipe up or down never arrives at all - the platform's own
    /// behaviour, and the same in a MAUI application written by hand. The page
    /// then holds the example still and scrolls the CODE instead, which is the
    /// part a reader scrolls anyway.
    static var scrolls: Bool { get }

    /// Which kinds of device LIST this sample. Everywhere unless a sample says
    /// otherwise; a sample about desktop chrome says `[.desktop]`.
    ///
    /// What it steers is the listing - the group's page, the home page's
    /// count, the "Surprise me" pick. The ROUTE still reaches the page on any
    /// device, deliberately: a link followed is better answered by the page
    /// saying what is missing than by a dead end.
    static var idioms: Set<DeviceIdiom> { get }

    /// The example, in PARTS. One part - the default, the sample itself - is
    /// a page with one EXAMPLE; a sample with two distinct halves names
    /// them, "EXAMPLE 1" and "EXAMPLE 2", and each becomes a tab of its own on
    /// a held page and a heading of its own on a scrolling one, with IN SWIFT
    /// after them. A part is its own ContentView so its `@State` is its own,
    /// carried by the catalog the gallery keeps, like the sample's.
    var parts: [SamplePart] { get }

    /// The words under the example - the paragraphs saying what it teaches.
    ///
    /// Declared APART from the example, rather than written as its last row,
    /// so the page can put them where there is room for them: under the example
    /// on a SCROLLING page, and in a NOTES tab of their own on a held one,
    /// where nothing scrolls and whatever does not fit is clipped away unsaid.
    ///
    /// A live READING - a tally, a count, "3 ticked" - is not a note and
    /// belongs in the example: it is what the example is doing, and a reader
    /// watching it must not have to change tabs to see it move.
    ///
    /// An `Element` and not a string, so the words are written the way every
    /// other view here is - `Palette.subtle`, the sizes, a `VStack` of two
    /// paragraphs - rather than in a second notation the page would have to
    /// interpret.
    var notes: Element? { get }

    /// Which parts show a TRAP rather than a way to do something, BY TITLE -
    /// `["EXAMPLE 2"]`. The warning triangle then appears beside that part's
    /// heading and beside the same words over its code, so a reader who lands
    /// on either half is told before they copy it.
    ///
    /// By title rather than by index because the code sections are cut from a
    /// `// -- TITLE --` marker and know nothing but their own words.
    static var warns: Set<String> { get }

    /// Whether the words stay UNDER the example on a held page rather than
    /// taking a tab of their own.
    ///
    /// A held page gives them a tab by default: nothing on such a page scrolls,
    /// so words under the example take the height the example wanted and
    /// whatever still does not fit is clipped away unsaid. A sample whose words
    /// are a couple of short paragraphs says otherwise and keeps them where the
    /// eye already is.
    static var notesUnder: Bool { get }

    /// Whether the example should be given the WINDOW's height rather than its
    /// own - true for an example that scrolls itself: a `LazyList`, a
    /// `ScrollView`, a WebView.
    ///
    /// Such an example needs a bounded height, and stating one in points is the
    /// wrong way to bound it: a list of `.heightRequest(240)` shows the same
    /// four rows on a phone and on a 27-inch screen, with the rest of the page
    /// empty under it. Filling the cell instead makes the example as tall as
    /// there is room for, and the thing inside it already knows how to scroll.
    ///
    /// Only ever true beside `scrolls == false`: a part inside the page's own
    /// scroller has no bounded height to fill.
    static var fills: Bool { get }
}

extension SampleContent {
    /// Nothing to warn about, which is what almost every sample says.
    static var warns: Set<String> { [] }

    /// An example as tall as it needs to be, which is what almost every sample
    /// is - only the ones that scroll themselves ask for the window's height.
    static var fills: Bool { false }

    /// Words in a tab of their own wherever the page holds still, which is what
    /// a sample says by saying nothing.
    static var notesUnder: Bool { false }

    /// One part, titled "EXAMPLE" - carrying the sample's own notes, since a
    /// sample with one part has nowhere else to declare them.
    var parts: [SamplePart] { [SamplePart(title: "EXAMPLE", view: self, notes: notes)] }

    /// No words but the summary, which is what most samples say.
    var notes: Element? { nil }

    /// No C# half, which is what almost every sample says.
    static var codeCSharp: String { "" }

    static var scrolls: Bool { true }

    /// Listed on every kind of device, which is what almost every sample is.
    static var idioms: Set<DeviceIdiom> { [.phone, .tablet, .desktop, .tv, .watch] }

}

/// One half of an example: the view, what to call it, and the words under it.
///
/// A type rather than a tuple: the chrome has to know where the example ends
/// and the explanation begins - a held page gives the words a tab of their
/// own - and a tuple's third field would say nothing at the call site about
/// which is which.
struct SamplePart {
    /// The tab's caption on a held page, the heading on a scrolling one, and
    /// what `warns` names when the part shows a trap. "EXAMPLE" where a sample
    /// has one part.
    let title: String

    /// The example itself, as a value whose content builds when the page does.
    let view: Element

    /// The words under it, where the part has any - in a NOTES tab of their own
    /// on a held page. See `SampleContent.notes`.
    let notes: Element?

    /// - Parameter notes: the words under the example, `nil` for a part that
    ///   explains itself in the summary alone.
    init(title: String, view: Element, notes: Element? = nil) {
        self.title = title
        self.view = view
        self.notes = notes
    }
}

/// A sample as the gallery holds it: the metadata read off the type, and the
/// example as a value that has not been built yet.
///
/// `Element` and not `SampleContent`, because an existential of a protocol with
/// static requirements cannot stand in for itself - and once the metadata has
/// been copied out there is nothing left to ask the type for.
struct Sample {
    let id: String
    let title: String
    let summary: String
    let code: String
    let codeCSharp: String
    let scrolls: Bool
    let idioms: Set<DeviceIdiom>

    /// The titles that carry a warning triangle - a part's heading and the code
    /// section wearing the same words.
    let warns: Set<String>

    /// Whether the example is given the window's height rather than its own.
    let fills: Bool

    /// Whether the words stay under the example rather than taking a tab.
    let notesUnder: Bool

    /// The example's parts, usually one. Stored as values: a part is a
    /// ContentView, so what is kept here is a placeholder whose content builds
    /// when the page does - and whose `@State` lives as long as the gallery
    /// that keeps this catalog.
    let parts: [SamplePart]

    /// Whether a device of `idiom` lists this sample. An UNKNOWN idiom - a
    /// headless test, a host that could not say - lists everything: hiding is
    /// a courtesy to the reader, and a test wants to see it all.
    func isShown(on idiom: DeviceIdiom) -> Bool {
        idiom == .unknown || idioms.contains(idiom)
    }

    init<Content: SampleContent>(_ content: Content) {
        id = Content.id
        title = Content.title
        summary = Content.summary
        code = Content.code
        codeCSharp = Content.codeCSharp
        scrolls = Content.scrolls
        idioms = Content.idioms
        warns = Content.warns
        fills = Content.fills
        notesUnder = Content.notesUnder
        parts = content.parts
    }
}

/// A sample IS its id: the catalog makes every sample once, so two with one id
/// are the same sample - which is what lets the page showing one be carried
/// when the window builds for a move somewhere else on the stack.
extension Sample: Equatable {
    static func == (a: Sample, b: Sample) -> Bool { a.id == b.id }
}
