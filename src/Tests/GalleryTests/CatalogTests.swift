// The gallery's catalog, and the arrangement built from it.
//
// The gallery is a sample app, so nothing here tests the library. What it tests
// is the LIST: every sample reachable by an id of its own, every group complete,
// and a menu row for each. That list is the thing this app will rot through - a
// sample renamed and not renamed everywhere, a group left empty, a card pointing
// at nothing - and none of it is visible until the app is running and someone
// taps the wrong row.
//
// Building the tree is the whole test harness: `createWindow().body` produces
// the Node tree the host would be sent, with no renderer, no host and no device
// involved. And WHERE THE GALLERY IS is state on this side - so a move is
// tested by firing the handler a reader would touch and reading the boxes it
// wrote, with no acts, no host and nothing to await.

import StateUIWireProbe
import XCTest
@testable import StateUI
@testable import GalleryUI

/// The gallery's navigation over boxes a test owns, so a move can be read back.
///
/// This is the whole reason the navigation tests below are three lines each: the
/// application's `@State` is private, but `Navigation` borrows rather than owns,
/// so a test lends it boxes of its own and then reads them.
private struct Place {
    let section = State<Section>(.home)
    let path = State<[Route]>([])
    let menu = State(false)
    let menuGesture = State(true)
    let sheets = State<[Sheet]>([])
    let inspectors = State<[Int]>([])
    let documents = State<[Int]>([])
    let tabs = State<[DemoTab]>(DemoTab.opening)
    let tab = State<DemoTab>(.stack)
    let tabsNote = State("")

    var nav: Navigation {
        Navigation(section: section.projectedValue,
                   path: path.projectedValue,
                   menuOpen: menu.projectedValue,
                   menuGesture: menuGesture.projectedValue,
                   sheets: sheets.projectedValue,
                   inspectors: inspectors.projectedValue,
                   documents: documents.projectedValue,
                   tabs: tabs.projectedValue,
                   tab: tab.projectedValue,
                   tabsNote: tabsNote.projectedValue)
    }
}

/// Everything a tree SAYS, node by node - one string, or the runs one spells.
///
/// A CodeBlock colours its snippet, and a MAUI Label has ONE TextColor, so six
/// colours are six Spans under a FormattedString and the text is what they
/// spell together.
private func shownTexts(in node: Node) -> [String] {
    var said: [String] = []

    func text(_ node: Node) -> String? { node.built.props["text"]?.string }

    func walk(_ node: Node) {
        let node = node.built

        if node.type == "FormattedString" {
            said.append(node.children.compactMap(text).joined())
        } else if let value = text(node) {
            said.append(value)
        }

        node.children.forEach(walk)
    }

    walk(node)

    return said
}

/// Every row of a menu, by what it says - a row being a view with a tap on it.
private func rowTitles(in node: Node) -> [String] {
    var titles: [String] = []

    func walk(_ node: Node) {
        let node = node.built

        if node.events["tapped"] != nil,
           let said = node.children.compactMap({ $0.built.props["text"]?.string }).first {
            titles.append(said)
        }

        node.children.forEach(walk)
    }

    walk(node)
    return titles
}

/// The tap on the row that says `title`.
private func rowHandler(_ title: String, in node: Node) -> EventHandler? {
    func walk(_ node: Node) -> EventHandler? {
        let node = node.built

        if let tap = node.events["tapped"],
           node.children.contains(where: { $0.built.props["text"]?.string == title }) {
            return tap
        }

        for child in node.children {
            if let hit = walk(child) { return hit }
        }

        return nil
    }

    return walk(node)
}

/// Runs a handler that ANIMATES before it acts, answering the host's side of it.
///
/// A card dips before it navigates - `press.scaleTo(...)`, awaited - so firing
/// its tap and reading state at once finds nothing: the handler is suspended on
/// an animation nobody answered. Every act taken is completed the way MAUI
/// answers an animation, and the jobs are drained between them, because the job
/// a resume produces does not exist yet at the moment the completion is
/// reported.
///
/// It also DECODES what it takes. A batch taken out of the renderer and thrown
/// away leaves names announced that the next reader has never heard of, and the
/// next test in this process dies on them.
///
/// It also RENDERS, which is what a flight needs and an act never did: an
/// animation is a state write now, and what carries it is the render the host
/// makes next. A test that only answered acts would leave the handler
/// suspended at its first `animateTo` for ever - which is exactly how this
/// helper failed the first time the card was migrated.
/// Says every walk in a patch landed, on the channel each named.
private func land(_ patch: Patch) {
    for transition in patch.transitions.values.sorted(by: { $0.channel > $1.channel }) {
        ReplyBuffer.current = .finished([.bool(true)])
        _ = Renderer.shared.dispatch(Int(transition.channel))
    }

    for child in patch.children {
        land(child)
    }
}

private func settle(
    _ handler: @escaping EventHandler,
    rendering renders: Renders? = nil,
    _ tree: (() -> Node)? = nil
) async {
    _ = WireProbe.decode(Renderer.shared.takeCommandsWire())
    Renderer.shared.start(handler)

    // Bounded rather than "until nothing is asked": a handler that asks for
    // ever should fail this test, not hang the suite.
    for _ in 0 ..< 16 {
        var carried = false

        // The render first: a flight is answered by the message that carries
        // it, or - when nothing armed on that state moved - by the settling
        // that follows the message.
        if let renders, let tree {
            land(renders.render(tree()))
            carried = true
        }

        let taken = WireProbe.decode(Renderer.shared.takeCommandsWire())

        guard !taken.isEmpty || carried else { break }

        for act in taken {
            guard let id = act.completion else { continue }

            ReplyBuffer.current = .finished([.bool(true)])
            _ = Renderer.shared.dispatch(id)
        }

        // The job a resume produces DOES NOT EXIST YET when the completion is
        // reported - Swift queues it a moment later - so this waits for work
        // rather than for a length of time. The deadline is a ceiling on a
        // failure, not a delay.
        let deadline = Date().addingTimeInterval(0.5)

        while Date() < deadline {
            if stateUIRunJobs() > 0 { break }

            try? await Task.sleep(nanoseconds: 100_000)
        }
    }
}

private func clicked(_ title: String, in node: Node) -> EventHandler? {
    func walk(_ node: Node) -> EventHandler? {
        let node = node.built

        if node.props["text"]?.string == title, let click = node.events["clicked"] {
            return click
        }

        for child in node.children {
            if let hit = walk(child) { return hit }
        }

        return nil
    }

    return walk(node)
}

/// A differ and the tree it last produced - the same harness StateUITests
/// calls Renders, small enough to repeat rather than share across packages.
private final class Renders {
    private let differ = Differ()
    private var rendered: RenderedNode?

    /// Renders a tree and returns what would have been sent.
    ///
    /// The flights are offered to the walk and settled after it, exactly as
    /// `Renderer.renderWire` does: an animation is a state write now, and a
    /// render that did not do this would carry the value and drop the walk.
    @discardableResult
    func render(_ tree: Node) -> Patch {
        let offered = Renderer.shared.offeredFlights()
        differ.flights = offered

        let result = differ.reconcile(rendered, with: tree)
        rendered = result.node

        Renderer.shared.settle(offered: offered, carried: differ.takeCarried())
        return result.patch
    }

    /// The closure an id refers to - the DIFFER's own, whose assigned controls
    /// the render filled. A closure walked off a freshly built tree is a
    /// different one: every build makes new values, and a `ControlState` is
    /// filled where the tree was rendered.
    func handler(_ id: Int) -> EventHandler? {
        differ.handler(id)
    }

    /// Runs the closure an id refers to, the way a dispatched event does.
    @discardableResult
    func fire(_ id: Int, with payload: [PropValue] = []) -> Bool {
        guard let handler = differ.handler(id) else { return false }

        EventBuffer.current = payload
        Renderer.shared.start(handler)
        return true
    }
}

/// The `tapped` closure on the tab captioned `title`, wherever it is.
///
/// A tab is a caption over a rule with a tap on the pair, so the node that
/// answers is the one holding a Label that says so - see Gallery/Views/Tabs.swift.
private func tabHandler(_ title: String, in node: Node) -> EventHandler? {
    func says(_ node: Node) -> Bool {
        if case .string(title)? = node.props["text"] { return true }

        return false
    }

    if let tap = node.events["tapped"], node.children.contains(where: says) {
        return tap
    }

    for child in node.children {
        if let hit = tabHandler(title, in: child) { return hit }
    }

    return nil
}

private extension String {
    /// How many times a one-character marker appears.
    func count(of marker: String) -> Int {
        filter { String($0) == marker }.count
    }
}

/// Whether a character is something a range could count FROM - its left side.
///
/// A name, a number, or the end of a call or a subscript. A bracket that OPENS
/// is not, which is what makes `(...)` an elision where `(1...5)` is a range.
private func countsFrom(_ character: Character?) -> Bool {
    guard let character else { return false }

    return character.isLetter || character.isNumber || "_)]".contains(character)
}

/// Whether a character is something a range could count TO - its right side.
///
/// A name, a number, a sign, or the start of a call or a subscript. A bracket
/// that CLOSES is not.
private func countsTo(_ character: Character?) -> Bool {
    guard let character else { return false }

    return character.isLetter || character.isNumber || "_$-([".contains(character)
}

/// The elision a line of sample code hides behind, where it hides behind one.
///
/// An elision is a `…`, or three dots standing on their own - `VStack { ... }`,
/// a lone `...` under a signature, `. . .` spread out. None of it compiles, and
/// a snippet carrying one is a sketch rather than the code it claims to be.
///
/// Two things spell three dots and are not elisions. Swift's RANGE operators
/// A sample's code with its `//` comments taken off, so a word written ABOUT
/// the example is not read as a word the example runs.
///
/// - Parameter code: A sample's `code` block.
/// - Returns: The same text with everything after a `//` removed, line by line.
private func stripComments(from code: String) -> String {
    code
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map { line -> Substring in
            guard let marker = line.range(of: "//") else { return line }

            return line[line.startIndex ..< marker.lowerBound]
        }
        .joined(separator: "\n")
}

/// Every `$name` written on its own in a snippet - the binding it lends.
///
/// A `$` after a dot (`nav.$menuOpen`) or inside a word is NOT one of these: the
/// first projects a property of something already declared, and the second is
/// part of a name. `$0` is a closure's argument and has no declaration to find,
/// so an identifier must start with a letter to count.
///
/// - Parameter code: A sample's `code`, comments already off.
/// - Returns: The names, without their `$`.
private func bareProjections(in code: String) -> Set<String> {
    var found: Set<String> = []
    var previous: Character = " "
    let characters = Array(code)
    var index = 0

    while index < characters.count {
        let character = characters[index]

        if character == "$", previous != ".", !previous.isLetter, !previous.isNumber,
           previous != "_" {
            var name = ""
            var scan = index + 1

            while scan < characters.count,
                  characters[scan].isLetter || characters[scan].isNumber
                    || characters[scan] == "_" {
                name.append(characters[scan])
                scan += 1
            }

            if let first = name.first, first.isLetter || first == "_" { found.insert(name) }
        }

        previous = character
        index += 1
    }

    return found
}

/// have an operand against them on one side or the other - `1...5`, `2...`,
/// `...5`, and `items.count + 1 ... items.count + 30` spread out - so the
/// neighbours are what tell them apart, and `..<` is never an elision at all.
/// And a STRING an example prints is text the sample SHOWS rather than code it
/// stands in for, so `"Dragging..."` reads past.
///
/// - Parameter line: One line of a sample's `code`.
/// - Returns: The elision as it is spelled, or nil where the line is all code.
private func elision(in line: String) -> String? {
    // The literals out and the spaces with them, so that `a ... b` and `a...b`
    // are the same three characters between the same two neighbours. A literal
    // leaves an identifier behind rather than a hole, which is what keeps
    // `("a"..."z")` reading as the range it is.
    var code = ""
    var quoted = false
    var escaped = false

    for character in line {
        switch character {
        case _ where escaped:
            escaped = false

        case "\\" where quoted:
            escaped = true

        case "\"":
            quoted.toggle()

            if !quoted {
                code.append("_")
            }

        case _ where quoted, " ", "\t":
            break

        default:
            code.append(character)
        }
    }

    if code.contains("…") {
        return "…"
    }

    let characters = Array(code)

    for start in characters.indices
    where start + 2 < characters.count
        && characters[start] == "."
        && characters[start + 1] == "."
        && characters[start + 2] == "." {
        let before = start > 0 ? characters[start - 1] : nil
        let after = start + 3 < characters.count ? characters[start + 3] : nil

        if !countsFrom(before) && !countsTo(after) {
            return "..."
        }
    }

    return nil
}

final class CatalogTests: XCTestCase {
    /// A catalog the way the application makes one, over a test's own boxes.
    private func catalog(_ nav: Navigation = Place().nav) -> Catalog {
        Catalog(nav: nav,
                listsHiddenRow: State(false).projectedValue,
                windowEvents: State([String]()).projectedValue)
    }

    /// The gallery's window over a given place - which is where the arrangement
    /// is declared, so this is what a test asks for a detail page.
    private func window(
        _ nav: Navigation,
        tabsPath: Binding<[Route]> = State<[Route]>([]).projectedValue
    ) -> MainWindow {
        MainWindow(catalog: catalog(nav),
                   nav: nav,
                   tabsPath: tabsPath,
                   listsHiddenRow: false,
                   note: { _ in })
    }

    // MARK: - The list

    func testEverySampleIsReachableByAnIdOfItsOwn() {
        let catalog = catalog()
        var seen: Set<String> = []

        for group in catalog.groups {
            for sample in group.samples {
                XCTAssertTrue(seen.insert(sample.id).inserted,
                              "two samples answer to \"\(sample.id)\"")

                // The id is what a card sends and what the route quotes back.
                XCTAssertEqual(catalog.sample(id: sample.id)?.title, sample.title)
            }
        }

        XCTAssertEqual(seen.count, catalog.sampleCount(on: .unknown))
        XCTAssertNil(catalog.sample(id: "nothing-called-this"))
    }

    /// A sample about desktop chrome is LISTED only on a desktop. The catalog
    /// still carries it - the route reaches the page on any device - what the
    /// idiom steers is the group page, the count and the "Surprise me" pick.
    /// An UNKNOWN idiom lists everything, which is why this headless test -
    /// and every other one here - sees the whole catalog.
    func testASampleAboutDesktopChromeIsListedOnlyOnADesktop() throws {
        let catalog = catalog()

        // The samples about things only a desktop has: the window's own bar,
        // and a menu MAUI attaches on Mac Catalyst and Windows alone
        // (ViewHandler.MapContextFlyout is an empty method on iOS and
        // Android - read from 10.0.20's IL).
        let desktopOnly: Set<String> = ["titleBar", "contextMenu"]

        for id in desktopOnly {
            let sample = try XCTUnwrap(catalog.sample(id: id))

            XCTAssertTrue(sample.isShown(on: .desktop), "\(id) is hidden on a desktop")
            XCTAssertFalse(sample.isShown(on: .phone), "\(id) is listed on a phone")
            XCTAssertFalse(sample.isShown(on: .tablet), "\(id) is listed on a tablet")
            XCTAssertTrue(sample.isShown(on: .unknown), "a headless test sees everything")
        }

        // And the one sample a TABLET can show as well: a second window needs
        // somewhere to put it, which an iPad has and a phone never will.
        let notOnAPhone: Set<String> = ["multi-window"]

        for id in notOnAPhone {
            let sample = try XCTUnwrap(catalog.sample(id: id))

            XCTAssertTrue(sample.isShown(on: .desktop), "\(id) is hidden on a desktop")
            XCTAssertTrue(sample.isShown(on: .tablet), "\(id) is hidden on a tablet")
            XCTAssertFalse(sample.isShown(on: .phone), "\(id) is listed on a phone")
        }

        // Every OTHER sample is everywhere: hiding is the exception, and one
        // hidden by accident would simply vanish from a phone with no test
        // the wiser.
        let hidden = desktopOnly.union(notOnAPhone)

        for group in catalog.groups {
            for other in group.samples where !hidden.contains(other.id) {
                XCTAssertTrue(other.isShown(on: .phone),
                              "\(other.id) is hidden on a phone")
            }
        }
    }

    func testEveryGroupIsWrittenOutInFull() {
        var routes: Set<String> = []

        for group in catalog().groups {
            XCTAssertFalse(group.samples.isEmpty, "\(group.title) has no samples")
            XCTAssertFalse(group.title.isEmpty)
            XCTAssertFalse(group.summary.isEmpty)

            // The icon is a file in Resources/Images, by the name MAUI gives it
            // once built - tab_list.svg is asked for as tab_list.png - and it is
            // drawn twice, because black artwork disappears on a dark page.
            XCTAssertTrue(group.icon.file.hasSuffix(".png"), "\(group.title): \(group.icon.file)")
            XCTAssertEqual(group.icon.dark, group.icon.file.replacingOccurrences(
                of: ".png", with: "_dark.png"), "\(group.title) has no dark twin")

            XCTAssertTrue(routes.insert(group.route).inserted,
                          "two groups answer to //\(group.route)")
        }
    }

    /// A `// -- TITLE --` line in a sample's code cuts it into sections, each
    /// shown under its own heading - the WebView sample names its two examples
    /// that way. Code without a marker is one untitled section, the block as
    /// it always was; the marker is a comment, so the snippet still compiles
    /// pasted whole.
    func testTheCodeSplitsWhereAMarkerNamesASection() throws {
        let sample = try XCTUnwrap(catalog().sample(id: "webView"))
        let sections = CodeBlock.sections(of: sample.code)

        XCTAssertEqual(sections.map(\.title), ["EXAMPLE 1", "EXAMPLE 2"])
        XCTAssertTrue(sections.allSatisfy { !$0.code.isEmpty })

        let plain = CodeBlock.sections(of: "let one = 1")
        XCTAssertEqual(plain.count, 1)
        XCTAssertNil(plain[0].title)
    }

    /// A sample with no summary or no code is half-written, and looks finished.
    func testEverySampleSaysWhatItIsAndHowItIsWritten() {
        for group in catalog().groups {
            for sample in group.samples {
                XCTAssertFalse(sample.title.isEmpty, "\(sample.id) has no title")
                XCTAssertFalse(sample.summary.isEmpty, "\(sample.id) has no summary")
                XCTAssertFalse(sample.code.isEmpty, "\(sample.id) shows no code")

                // Every part of the example is a view like any other, and has
                // to describe itself without being on a page. A part with an
                // empty title would draw a blank tab.
                for part in sample.parts {
                    XCTAssertFalse(part.title.isEmpty, "\(sample.id) has an untitled part")
                    XCTAssertFalse(part.view.body.built.type.name.isEmpty)
                }
            }
        }
    }

    /// The code beside an example is REAL code, not a sketch of one.
    ///
    /// What a reader sees under "IN SWIFT" is the sample's own view code with
    /// the decoration taken out - the layout and the meaning of the example,
    /// nothing invented. A sketch is what that rots into: `Border { … }`,
    /// `VStack { ... }`, a structure that stops halfway, a type the sample does
    /// not use. None of it would compile if it were pasted back, and nothing
    /// else here would notice.
    ///
    /// So: no placeholders, and balanced brackets. Neither proves the snippet is
    /// the sample's own code - only a reader can see that - but both fail on the
    /// two ways it stops being code at all. A placeholder is read line by line,
    /// because BOTH spellings of one are three characters a range operator also
    /// spells - see `elision(in:)` - and because a line number is what makes a
    /// failure findable in a block forty lines long.
    func testEverySamplesCodeIsCodeRatherThanASketch() {
        for group in catalog().groups {
            for sample in group.samples {
                let lines = sample.code.split(separator: "\n", omittingEmptySubsequences: false)

                for (index, line) in lines.enumerated() {
                    if let placeholder = elision(in: String(line)) {
                        XCTFail("\(sample.id) line \(index + 1) elides with `\(placeholder)` "
                                + "rather than showing what it runs: \(line)")
                    }
                }

                for (opening, closing) in [("{", "}"), ("(", ")"), ("[", "]")] {
                    XCTAssertEqual(
                        sample.code.count(of: opening), sample.code.count(of: closing),
                        "\(sample.id) has unbalanced \(opening)\(closing) - the snippet "
                        + "stops before the code it shows does")
                }
            }
        }
    }

    /// A snippet that PLACES a child in a grid has to show the grid.
    ///
    /// `.gridRow(1)` on a top-level view is the shape a sample falls into when
    /// its code is copied out of a `content` that wraps everything in a `Grid`:
    /// the placement comes along and the container does not. Pasted back it does
    /// not compile, and for a list sample it is worse than that - the star row
    /// is what gives a `CollectionView` its height, so a reader who drops it gets a
    /// list with nowhere to be.
    func testEverySamplesCodeShowsTheGridItPlacesChildrenIn() {
        let placements = ["gridRow(", "gridColumn(", "gridRowSpan(", "gridColumnSpan("]

        for group in catalog().groups {
            for sample in group.samples {
                let code = sample.code

                guard placements.contains(where: { code.contains(".\($0)") }) else { continue }

                XCTAssertTrue(
                    code.contains("Grid {") || code.contains("Grid("),
                    "\(sample.id) places a child with .gridRow or .gridColumn and shows no "
                    + "Grid around it - pasted back, that does not compile")
            }
        }
    }

    /// A snippet that LENDS a binding has to declare what it is lending.
    ///
    /// `Switch($listsHiddenRow)` with no `listsHiddenRow` above it reads as
    /// working code and answers "cannot find it in scope" the moment anybody
    /// tries it. Only a BARE `$name` is checked: `nav.$menuOpen` projects a
    /// property of a value that is declared, and demanding a declaration for
    /// that would push app-level plumbing back into snippets that are better
    /// without it.
    func testEverySamplesCodeDeclaresTheBindingsItLends() {
        for group in catalog().groups {
            for sample in group.samples {
                let code = stripComments(from: sample.code)

                for name in bareProjections(in: code) {
                    XCTAssertTrue(
                        code.contains("var \(name)") || code.contains("let \(name)"),
                        "\(sample.id) lends $\(name) and never declares it - pasted back, "
                        + "that does not compile")
                }
            }
        }
    }

    /// A HELD example shows no paragraphs: its words are declared as `notes`.
    ///
    /// A page that cannot scroll gives the example and the words ONE screen
    /// between them, so an explanation written as the example's last row is
    /// taken out of the example - measured on an iPhone SE, two paragraphs left
    /// a list three rows. Declared as `notes` the same words sit under the
    /// example where there is room for both and move to a NOTES tab where there
    /// is not.
    ///
    /// What tells the two apart is LENGTH. A held example says short things -
    /// a caption on a box, a reading it writes as it runs, "Tapped 3 time(s)" -
    /// and the longest of them across the whole gallery is little more than
    /// half this bound, while a paragraph runs to three or four times it.
    func testAHeldExamplePutsItsParagraphsInItsNotes() {
        // The longest a held example's text may be. The exception is a
        // WARNING: `rowState`'s second example shows what NOT to rely on, and
        // says so above the list, where somebody who only tries the example
        // reads it - which the NOTES tab cannot promise.
        let bound = 100
        let warns: Set<String> = ["rowState"]

        for group in catalog().groups {
            for sample in group.samples where !sample.scrolls && !warns.contains(sample.id) {
                for part in sample.parts {
                    for said in shownTexts(in: part.view.body.built) where said.count > bound {
                        XCTFail("\(sample.id) explains itself inside the example - "
                                + "\"\(said.prefix(60))...\" - and a held page has one "
                                + "screen for the example and the words together, so the "
                                + "words belong in `notes`")
                    }
                }
            }
        }
    }

    // MARK: - The arrangement built from it

    /// The gallery is a menu over a stack, and both halves are pages.
    ///
    /// Every structural claim the rest of this app rests on: the flyout holds
    /// two children wearing the identity of their halves, the pane has the title
    /// MAUI insists on, and the detail is a stack that opens on its root alone.
    func testTheWindowIsAMenuOverAStack() throws {
        let window = GalleryApp().createWindow().body.built

        XCTAssertEqual(window.type, "Window")

        let flyout = try XCTUnwrap(window.children.first)

        XCTAssertEqual(flyout.type, "FlyoutPage")
        XCTAssertEqual(flyout.props["isPresented"], .bool(false))
        XCTAssertEqual(flyout.props["flyoutLayoutBehavior"], .enumeration(1))
        XCTAssertNotNil(flyout.events["isPresentedChanged"],
                        "a swipe that closes the menu would not reach the binding")

        XCTAssertEqual(flyout.children.compactMap { $0.id }, ["flyout", "detail"])

        let pane = try XCTUnwrap(flyout.children.first).built

        XCTAssertEqual(pane.type, "ContentPage")
        XCTAssertNotNil(pane.props["title"], "MAUI refuses a flyout page with no title")

        let detail = try XCTUnwrap(flyout.children.last).built

        XCTAssertEqual(detail.type, "NavigationPage")
        XCTAssertNotNil(detail.props["barBackgroundColor"], "the bar is left to the platform")
        XCTAssertNotNil(detail.props["barTextColor"])
        XCTAssertNotNil(detail.events["popped"], "a back gesture would not reach the path")
        XCTAssertEqual(detail.children.count, 1, "the stack opens on its root alone")
    }

    /// And a SECOND list beside the page: what is presented over all of it,
    /// which is the window's rather than any page's.
    func testTheWindowCarriesAModalStack() throws {
        let window = GalleryApp().createWindow().body.built

        let presented = try XCTUnwrap(window.children.first { $0.type == "ModalStack" })

        XCTAssertEqual(presented.children.count, 0, "the gallery opens with nothing over it")
        XCTAssertNotNil(window.events["modalPopped"],
                        "a sheet the reader drags down would not reach the array")
    }

    /// Presenting and closing are the array growing and shrinking - the same
    /// two moves a navigation path has, one level up.
    func testPresentingAndClosingAreTheArray() {
        let place = Place()

        place.nav.present(.page(.pageSheet))
        XCTAssertEqual(place.sheets.wrappedValue, [.page(.pageSheet)])

        place.nav.present(.card)
        XCTAssertEqual(place.sheets.wrappedValue.count, 2, "a sheet may present a sheet")

        place.nav.dismiss()
        XCTAssertEqual(place.sheets.wrappedValue, [.page(.pageSheet)])

        place.nav.dismiss()
        XCTAssertTrue(place.sheets.wrappedValue.isEmpty)

        place.nav.dismiss()
        XCTAssertTrue(place.sheets.wrappedValue.isEmpty, "and closing nothing is nothing")
    }

    /// The gallery has ONE window until something opens another, which is what
    /// every application written before this had.
    func testTheGalleryOpensWithOneWindow() {
        XCTAssertEqual(GalleryApp().windows.count, 1)
    }

    /// Opening an inspector adds a window to the list, and it carries the
    /// number as its IDENTITY - the one thing the library cannot do for the
    /// author, and the reason closing the middle window closes that one.
    func testOpeningAnInspectorAddsAWindowThatKnowsWhichItIs() throws {
        let place = Place()

        place.nav.openInspector()
        place.nav.openInspector()

        XCTAssertEqual(place.inspectors.wrappedValue, [1, 2])

        let windows = GalleryApp().inspectorWindows(place.nav)

        XCTAssertEqual(windows.map { $0.body.id }, ["1", "2"])
        XCTAssertEqual(windows.last?.body.built.props["title"]?.string, "Inspector 2")
    }

    /// A window the READER closed is folded back by the handler written on it,
    /// which is `destroying` - and the number leaves the list, so the next
    /// render describes one window fewer.
    func testTheWindowsDestroyingHandlerClosesTheInspector() async throws {
        let place = Place()
        place.nav.openInspector()

        let windows = GalleryApp().inspectorWindows(place.nav)
        let destroying = try XCTUnwrap(windows.last?.body.built.events["destroying"])

        try await destroying()

        XCTAssertEqual(place.inspectors.wrappedValue, [])
    }

    /// And closing by number is the same move from this end - by VALUE, so it
    /// stays right whichever end asked.
    func testClosingAnInspectorTakesThatOneOut() {
        let place = Place()

        place.nav.openInspector()
        place.nav.openInspector()
        place.nav.closeInspector(1)

        XCTAssertEqual(place.inspectors.wrappedValue, [2])

        place.nav.openInspector()
        XCTAssertEqual(place.inspectors.wrappedValue, [2, 3], "a number in use is never reissued")
    }

    /// The menu lists Home, every group, and the one row that performs an act.
    ///
    /// A Shell built these rows from items it held; this walks the page the app
    /// wrote, which is what the reader taps.
    func testTheMenuHasARowForHomeEveryGroupAndTheActAtTheEnd() {
        let catalog = catalog()
        let menu = MenuPage(catalog: catalog, nav: Place().nav,
                            listsHiddenRow: false, surprise: {})

        XCTAssertEqual(rowTitles(in: menu.body),
                       ["Home"] + catalog.groups.map { $0.title } + ["Surprise me"])
    }

    /// The row the menu does not always list, which is an `if` and nothing more
    /// - and the page behind it is reachable either way, because a section is a
    /// value rather than a row.
    func testTheUnlistedRowIsDrawnOnlyWhenItIsToldTo() throws {
        let place = Place()
        let menu = { (lists: Bool) in
            MenuPage(catalog: self.catalog(place.nav), nav: place.nav,
                     listsHiddenRow: lists, surprise: {})
        }

        XCTAssertFalse(rowTitles(in: menu(false).body).contains("Not in the list"))
        XCTAssertTrue(rowTitles(in: menu(true).body).contains("Not in the list"))

        // And the section itself needs no row: this is what the sample's
        // "Go there anyway" button does.
        place.nav.open(.hidden)
        XCTAssertEqual(place.section.wrappedValue, .hidden)
    }

    /// Choosing a section is three writes and no await: the section, the empty
    /// path, and the menu closing behind it.
    ///
    /// In MAUI's Shell the same move is an awaited `GoToAsync("//route")`,
    /// answered by the framework, with the section it LEFT still holding
    /// whatever had been pushed there.
    func testChoosingASectionMovesTheApplicationAndClosesTheMenu() throws {
        let place = Place()
        place.path.wrappedValue = [.sample("grid")]
        place.menu.wrappedValue = true

        let menu = MenuPage(catalog: catalog(place.nav), nav: place.nav,
                            listsHiddenRow: false, surprise: {})

        Renderer.shared.start(try XCTUnwrap(rowHandler("Layout", in: menu.body)))

        XCTAssertEqual(place.section.wrappedValue, .home, "a group stands ON home")
        XCTAssertEqual(
            place.path.wrappedValue, [.group("layout")],
            "the group replaces whatever was pushed, and is itself pushed onto home")
        XCTAssertFalse(place.menu.wrappedValue, "the menu stayed open over the page it opened")
    }

    /// A card on a group's page PUSHES the sample it names, with the id riding
    /// as a value of the route.
    ///
    /// Through a DIFFER and with the animation answered, because a card dips
    /// before it navigates: the handle it aims at is filled while the tree is
    /// rendered, and the push is what happens after the dip.
    func testACardPushesTheSampleItNames() async throws {
        let place = Place()
        let group = try XCTUnwrap(catalog(place.nav).groups.first { $0.route == "layout" })
        let sample = try XCTUnwrap(group.shown(on: .unknown).first)

        let renders = Renders()
        let patch = renders.render(GroupPage(group: group, nav: place.nav).body)
        let tapped = try XCTUnwrap(eventId("tapped", in: patch), "no card answers a tap")

        await settle(
            try XCTUnwrap(renders.handler(tapped)),
            rendering: renders,
            { GroupPage(group: group, nav: place.nav).body })

        XCTAssertEqual(place.path.wrappedValue, [.sample(sample.id)])
    }

    /// The way home is ONE assignment. In MAUI's Shell it is three awaited
    /// calls - ask where you are, switch, then empty the section you left by
    /// the name you read on the way out - because a Shell keeps one stack per
    /// section and hands it back.
    func testTheWayHomeIsOneAssignment() throws {
        let place = Place()
        place.path.wrappedValue = [.group("layout"), .sample("grid"), .level(1)]

        let home = try XCTUnwrap(ToolbarItem.home(place.nav).body.events["clicked"])
        Renderer.shared.start(home)

        XCTAssertEqual(place.section.wrappedValue, .home)
        XCTAssertEqual(place.path.wrappedValue, [])
    }

    // MARK: - The section that is not a stack

    /// One section is arranged as tabs, which a Shell could not do at all: a Tab
    /// was shell structure, so its pages could only be declared beside the
    /// flyout items and reached by a route.
    ///
    /// The first tab holds a whole navigation stack, and its caption and picture
    /// are the STACK's - measured, and where the first live run of TabbedPage
    /// showed no icons at all.
    func testTheTabsSectionIsATabbedPageWithAStackInsideIt() throws {
        let place = Place()
        place.section.wrappedValue = .tabs

        let tabsPath = State<[Route]>([])

        let detail = window(place.nav,
                            tabsPath: tabsPath.projectedValue).detail().body

        XCTAssertEqual(detail.type, "TabbedPage")
        XCTAssertEqual(detail.props["currentPage"], .number(0))
        XCTAssertNotNil(detail.events["currentPageChanged"],
                        "a tab tapped - or swiped, on Android - would not reach the binding")
        XCTAssertEqual(detail.children.count, DemoTab.opening.count)

        let stack = try XCTUnwrap(detail.children.first)

        XCTAssertEqual(stack.type, "NavigationPage")
        XCTAssertEqual(stack.props["title"], .string("Stack"))
        XCTAssertNotNil(stack.props["iconImageSource"], "a tab with no picture")

        let second = try XCTUnwrap(detail.children.last).built

        XCTAssertEqual(second.props["title"], .string("Second"))
        XCTAssertNotNil(second.props["iconImageSource"])
    }

    /// Each tab keeps its own place because the ARRAYS are separate - which is
    /// Reversing the tabs from the MIDDLE of three describes the same
    /// `currentPage` as before it - which is the whole point of the move.
    ///
    /// A property is sent only when its value changed, so this message carries
    /// no selection at all while the children are rearranged underneath it. The
    /// host has to remember what was showing to survive that, and this pins the
    /// premise: if the number ever differed, the press would prove nothing.
    func testReversingTheTabsLeavesAMiddleSelectionAtTheSameIndex() throws {
        let place = Place()
        place.section.wrappedValue = .tabs
        place.tabs.wrappedValue = [.stack, .second, .extra(1)]
        place.tab.wrappedValue = .second

        let before = window(place.nav).detail().body.props["currentPage"]

        place.nav.reverseTabs(showing: .second)

        let after = window(place.nav).detail().body.props["currentPage"]

        XCTAssertEqual(place.tabs.wrappedValue, [.extra(1), .second, .stack])
        XCTAssertEqual(before, .number(1))
        XCTAssertEqual(after, before, "the reversal moved the selection's index")
    }

    /// Closing the tab being LOOKED AT leaves the selection naming no tab, so
    /// the message carries no `currentPage` and the platform has to choose.
    func testClosingTheShowingTabLeavesTheSelectionNamingNothing() throws {
        let place = Place()
        place.section.wrappedValue = .tabs
        place.tabs.wrappedValue = [.stack, .second]
        place.tab.wrappedValue = .second

        place.nav.closeTab(.second, showing: .second)

        XCTAssertEqual(place.tabs.wrappedValue, [.stack])
        XCTAssertNil(window(place.nav).detail().body.props["currentPage"],
                     "a selection naming no tab must describe no index")
    }

    /// The last tab stays: a tab bar with nothing in it draws no page, and
    /// there would be nothing left to press.
    func testTheLastTabCannotBeClosed() {
        let place = Place()
        place.tabs.wrappedValue = [.stack]

        place.nav.closeTab(.stack, showing: .stack)

        XCTAssertEqual(place.tabs.wrappedValue, [.stack])
    }

    /// the one claim the tabs sample makes that nothing else would catch.
    func testATabsStackIsAnArrayOfItsOwn() throws {
        let place = Place()
        place.section.wrappedValue = .tabs

        let tabsPath = State<[Route]>([])

        let detail = window(place.nav,
                            tabsPath: tabsPath.projectedValue).detail().body

        let stack = try XCTUnwrap(detail.children.first)
        let root = try XCTUnwrap(stack.children.first).built

        Renderer.shared.start(try XCTUnwrap(clicked("Push a page onto this tab", in: root)))

        XCTAssertEqual(tabsPath.wrappedValue, [.level(1)])
        XCTAssertEqual(place.path.wrappedValue, [], "the tab pushed onto the gallery's stack")
    }

    /// Every page under the tabs offers the way back out, the menu drawing no
    /// row for that section. Nothing else would notice it going missing - the
    /// pages would simply be a trap.
    func testEveryPageUnderTheTabsHasAWayBackToTheSamples() throws {
        let place = Place()
        place.section.wrappedValue = .tabs

        let tabsPath = State<[Route]>([])

        let detail = window(place.nav,
                            tabsPath: tabsPath.projectedValue).detail().body

        for (index, child) in detail.children.enumerated() {
            // The first tab is a stack, so the page to read is its root.
            let page = child.type == "NavigationPage"
                ? try XCTUnwrap(child.children.first).built
                : child.built

            place.section.wrappedValue = .tabs

            let back = try XCTUnwrap(
                clicked("Back to the Navigation samples", in: page),
                "tab \(index) has no way back")

            Renderer.shared.start(back)

            XCTAssertEqual(place.section.wrappedValue, .home)
            XCTAssertEqual(place.path.wrappedValue, [.group("navigation")])
        }
    }

    /// Every card answers a tap on the CARD, not on something inside it.
    ///
    /// This is the whole of what a gallery does, and it was wrong once: the
    /// chevron carried the handler, so the row looked tappable and only that one
    /// glyph was.
    func testEveryCardOnEveryPageAnswersATap() throws {
        let catalog = catalog()

        try assertEveryCardIsTappable(in: HomePage(catalog: catalog, nav: Place().nav).body.built,
                                      expecting: catalog.groups.count)

        for group in catalog.groups {
            try assertEveryCardIsTappable(in: GroupPage(group: group, nav: Place().nav).body.built,
                                          expecting: group.samples.count)
        }
    }

    /// Finds what answers a tap and insists there is one per thing listed, each
    /// on the CARD.
    ///
    /// Counts the handlers rather than the Borders, and says what carries each.
    /// Both halves matter and they are the two ways this has been wrong: too few
    /// handlers is a row that does not answer, and a handler on anything but the
    /// Border is the original defect - the chevron carried it, so the row looked
    /// tappable and only that one glyph was.
    ///
    /// A Border is not by itself a card. The home page opens with one that is a
    /// PANEL - the mark and the name on the identity gradient - and counting
    /// shapes rather than handlers made a decoration look like a missing row.
    private func assertEveryCardIsTappable(
        in page: Node,
        expecting count: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        var carriers: [String] = []

        func walk(_ node: Node) {
            if node.events["tapped"] != nil {
                carriers.append(node.type.name)
            }

            node.children.forEach(walk)
        }

        walk(page)

        XCTAssertEqual(carriers.count, count,
                       "the page answers a tap in something other than \(count) places",
                       file: file, line: line)

        XCTAssertEqual(Set(carriers), ["Border"],
                       "a tap is answered by \(Set(carriers).sorted()) rather than by the card",
                       file: file, line: line)
    }

    /// A gesture sample is shown on a page that does not scroll under it.
    ///
    /// A ScrollView claims a drag before the view under it hears about it: a pan
    /// inside one reports nothing vertically, and a swipe up or down never
    /// arrives at all. That is the platform's own behaviour and it would be the
    /// same in a MAUI application written by hand - so the page holds the
    /// example still and scrolls the CODE instead, which is the part a reader
    /// scrolls anyway.
    func testAGestureSampleIsNotShownInsideAScroller() throws {
        let group = try XCTUnwrap(catalog().groups.first { $0.route == "gestures" })

        // The recognizers this library has. A sample that carries one of these
        // must not have a scroller above it.
        let gestures: Set<String> = [
            "tapped", "swiped", "panUpdated", "pinchUpdated",
            "pointerEntered", "pointerExited", "pointerMoved",
            "pointerPressed", "pointerReleased",
            "dragStarting", "dropCompleted", "drop", "dragOver", "dragLeave",
        ]

        for sample in group.samples {
            XCTAssertFalse(sample.scrolls, "\(sample.id) says its page may scroll")

            var caught: [String] = []
            var codeScrolls = false
            var found = 0
            var tabs: [Int] = []

            /// What a node says, whether that is one string or a set of runs.
            ///
            /// A CodeBlock colours its snippet, and a MAUI Label has ONE
            /// TextColor - so six colours are six Spans under a FormattedString,
            /// and the text is what they spell when joined.
            func shownText(_ node: Node) -> String? {
                func text(_ node: Node) -> String? {
                    if case .string(let value)? = node.props["text"] { return value }

                    return nil
                }

                if let value = text(node) { return value }
                guard node.type == "FormattedString" else { return nil }

                return node.children.compactMap(text).joined()
            }

            func walk(_ node: Node, scrolled: Bool) {
                let scrolled = scrolled || node.type == "ScrollView"
                let handled = node.events.keys.map(\.name).filter { gestures.contains($0) }

                found += handled.count

                if scrolled {
                    caught.append(contentsOf: handled)

                    // The code is the one thing that DOES scroll. It is drawn as
                    // coloured runs rather than one string, so the runs are put
                    // back together to recognize it.
                    codeScrolls = codeScrolls || shownText(node) == sample.code
                }

                node.children.forEach { walk($0, scrolled: scrolled) }
            }

            // BOTH tabs, because the page shows one at a time and each has to
            // hold on its own: the example must never be under a scroller, and
            // the code must always be under one.
            //
            // The tab is TAPPED rather than the state being set, because the
            // state is the page's own and a test has no business reaching into
            // it - and tapping is what a reader does anyway. The handler is on
            // the node, so no differ and no host are needed to run it.
            let page = SamplePage(sample: sample, nav: Place().nav)

            for title in ["EXAMPLE", "IN SWIFT"] {
                guard let tap = tabHandler(title, in: page.body.built) else { continue }

                tabs.append(tabs.count)
                Renderer.shared.start(tap)
                walk(page.body.built, scrolled: false)
            }

            XCTAssertEqual(tabs.count, 2, "\(sample.id) does not offer the example and the code")
            XCTAssertGreaterThan(found, 0, "\(sample.id) is a gesture sample with no gesture on it")
            XCTAssertEqual(caught, [], "\(sample.id) would lose \(caught) to the page's scroller")
            XCTAssertTrue(codeScrolls, "\(sample.id) shows its code with no way to scroll it")
        }
    }

    /// The pinch sample scales a CHILD of the view the recognizer is on.
    ///
    /// A view that transforms itself while a gesture is running can cancel that
    /// gesture on the platform side - a pinch that reports once and then stops.
    /// MAUI's own sample splits the two for the same reason, and this test is
    /// here because the split looks like an accident until it is explained.
    func testThePinchSampleDoesNotScaleTheViewItsGestureIsOn() throws {
        let sample = try XCTUnwrap(catalog().sample(id: "pinch"))

        var pinched: [Node] = []
        var scaled: [Node] = []

        func walk(_ node: Node) {
            if node.events["pinchUpdated"] != nil { pinched.append(node) }
            if node.props["scale"] != nil { scaled.append(node) }
            node.children.forEach(walk)
        }

        for part in sample.parts {
            walk(part.view.body.built)
        }

        XCTAssertEqual(pinched.count, 1)
        XCTAssertEqual(scaled.count, 1)

        XCTAssertNil(pinched.first?.props["scale"],
                     "the recognizer is on the view it transforms, which is what stops a pinch")
        XCTAssertNil(scaled.first?.events["pinchUpdated"])
    }

    /// The pinch works on a platform that never sends `.started`.
    ///
    /// Measured, not assumed: on Mac Catalyst a trackpad magnification arrives
    /// as `.running` then `.completed` - each step its own short cycle, with no
    /// `.started` at all. MAUI's own sample captures the scale on `.started` and
    /// would sit there doing nothing; multiplying by what each report carries
    /// needs no such thing.
    func testThePinchSampleDoesNotWaitForAStatusThatMayNeverCome() throws {
        // The sample owns its state now, so the test goes through a render the
        // way the app does: fire the handler C# would, read the scale that
        // lands on the tree.
        let renders = Renders()

        let first = renders.render(PinchSample().body)
        let pinchUpdated = try XCTUnwrap(eventId("pinchUpdated", in: first))

        // Exactly what the platform sent, in the order it sent it.
        renders.fire(pinchUpdated, with: [
            .enumeration(GestureStatus.running.rawValue), .number(1.02), .numbers([0.5, 0.45]),
        ])
        renders.fire(pinchUpdated, with: [
            .enumeration(GestureStatus.completed.rawValue), .number(1), .numbers([0, 0]),
        ])

        let second = renders.render(PinchSample().body)
        XCTAssertEqual(try XCTUnwrap(number("scale", in: second)), 1.02, accuracy: 0.0001,
                       "the scale did not follow a pinch that never said .started")

        // And a second gesture goes on from where the first left off.
        renders.fire(pinchUpdated, with: [
            .enumeration(GestureStatus.running.rawValue), .number(1.02), .numbers([0.5, 0.45]),
        ])

        let third = renders.render(PinchSample().body)
        XCTAssertEqual(try XCTUnwrap(number("scale", in: third)), 1.0404, accuracy: 0.0001)
    }

    /// The id a patch assigned to an event, wherever in the tree it landed.
    private func eventId(_ event: Event, in patch: Patch) -> Int? {
        if let id = patch.events?[event] { return id }

        for child in patch.children {
            if let id = eventId(event, in: child) { return id }
        }

        return nil
    }

    /// The first value a patch carries for a property, wherever it landed.
    private func number(_ prop: Prop, in patch: Patch) -> Double? {
        if case .number(let value)? = patch.props[prop] { return value }

        for child in patch.children {
            if let value = number(prop, in: child) { return value }
        }

        return nil
    }

}
