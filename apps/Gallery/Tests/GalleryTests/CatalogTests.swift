// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The gallery's catalog, and the arrangement built from it.
//
// The gallery is a sample app, so nothing here tests the library. What it tests
// is the LIST: every sample reachable by an id of its own, every group complete,
// and a menu row for each. That list is the thing this app will rot through - a
// sample renamed and not renamed everywhere, a group left empty, a card pointing
// at nothing - and none of it is visible until the app is running and someone
// taps the wrong row.
//
// Building the tree is the whole test harness: `GalleryScene().windows.main.body` produces
// the Node tree the host would be sent, with no renderer, no host and no device
// involved. And WHERE THE GALLERY IS is state on this side - so a move is
// tested by firing the handler a reader would touch and reading the boxes it
// wrote, with no acts, no host and nothing to await.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI
@testable import GalleryUI

private extension HostPatch {
    var props: [Prop: HostValue] { properties }
}

private extension HostEventUpdate {
    var handlers: [Event: Int32] {
        switch self {
        case .replace(let handlers): handlers
        }
    }

    subscript(event: Event) -> Int32? { handlers[event] }
}

/// A gallery's navigation of a test's own, so a move can be read back.
///
/// This is the whole reason the navigation tests below are three lines each:
/// `Navigation` is a class of `@State` properties, so a test makes one, hands
/// it to what it builds, and reads each property's state through its `$`.
private struct Place {
    let nav = Navigation()

    var section: Binding<Section> { nav.$section }
    var path: Binding<[Route]> { nav.$path }
    var menu: Binding<Bool> { nav.$menuOpen }
    var sheets: Binding<[Sheet]> { nav.$sheets }
    var tabs: Binding<[DemoTab]> { nav.$tabs }
    var tab: Binding<DemoTab> { nav.$tab }
    var tabsPath: Binding<[Route]> { nav.$tabsPath }
    var tabsNote: Binding<String> { nav.$tabsNote }
}

/// A sample that FILLS its cell and scrolls itself, which is the shape the
/// page has to carry without a stack in the way.
private struct Filling: SampleContent, ExampleContent {
    static let id = "filling"
    static let title = "Fills its cell"
    static let summary = "A scroller given the whole of the cell."
    static let code = "ScrollView { Label(\"row\") }"
    static let scrolls = false
    static let fills = true

    var content: any View {
        ScrollView {
            Label("row")
        }
    }

    var notes: Element? { nil }
}

private extension Sample {
    /// Every listing on the sample's page as one text - what a check over all
    /// of a sample's Swift reads.
    var code: String { examples.map(\.code).joined(separator: "\n\n") }
}

/// The headings a tree shows, in order - what a reader moving by heading
/// lands on.
private func headings(in node: Node) -> [String] {
    var found: [String] = []

    func walk(_ node: Node) {
        let node = node.built

        if node.props[.semanticHeadingLevel] != nil, let text = node.props["text"]?.string {
            found.append(text)
        }

        node.children.forEach(walk)
    }

    walk(node)
    return found
}

/// How many scrollers in a tree move down rather than only across.
private func verticalScrollers(in node: Node) -> Int {
    var count = 0

    func walk(_ node: Node) {
        let node = node.built

        if node.type == "ScrollView",
           node.props["orientation"] != .enumeration(ScrollOrientation.horizontal.rawValue) {
            count += 1
        }

        node.children.forEach(walk)
    }

    walk(node)
    return count
}

/// Everything a tree SAYS, node by node - one string, or the runs one spells.
///
/// A `CodeBlock` colours its snippet with spans under one formatted label, so
/// the visible text is what those runs spell together.
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

/// Runs a handler that animates before it acts, answering the host's side of it.
///
/// A card dips before it navigates - `press.scaleTo(...)`, awaited - so firing
/// its tap and reading state at once finds nothing: the handler is suspended on
/// an animation nobody answered. Every command taken is completed through the
/// typed host boundary, and the jobs are drained between them, because the job
/// a resume produces does not exist yet at the moment the completion is
/// reported.
///
/// It also RENDERS, which is what a journey needs and an act never did: an
/// animation is a state write now, and what carries it is the render the host
/// makes next. A test that only answered acts would leave the handler
/// suspended at its first `move(to:)` for ever - which is exactly how this
/// helper failed the first time the card was migrated.

private func settle(
    _ handler: @escaping EventHandler,
    rendering renders: Renders? = nil,
    _ tree: (() -> Node)? = nil
) async {
    _ = StateUIHost.takeCommands()
    Renderer.shared.start(handler)

    // Bounded rather than "until nothing is asked": a handler that asks for
    // ever should fail this test, not hang the suite.
    for _ in 0 ..< 16 {
        var carried = false

        // The render first: what a handler awaits is a movement on a DRIVEN
        // state, and the render is what registers the property it is carried
        // on.
        if let renders, let tree {
            renders.render(tree())
            carried = true
        }

        // AND WHATEVER A DRIVEN STATE IS WAITING ON, which no patch mentions:
        // a movement there is booked against a LANE of the image and answered
        // by the host reading it. Nothing here plays the host, so the arrival
        // is granted.
        for id in Renderer.shared.waiting {
            ReplyBuffer.current = .finished([.bool(true)])

            if Renderer.shared.dispatch(id) {
                carried = true
            }
        }

        let taken = StateUIHost.takeCommands()

        guard !taken.isEmpty || carried else { break }

        for act in taken {
            guard let id = act.completion else { continue }
            _ = StateUIHost.complete(id, succeeded: true)
        }

        // The job a resume produces DOES NOT EXIST YET when the completion is
        // reported - Swift queues it a moment later - so this waits for work
        // rather than for a length of time. The deadline is a ceiling on a
        // failure, not a delay.
        let deadline = Date().addingTimeInterval(0.5)

        while Date() < deadline {
            if StateUIHost.runJobs() > 0 { break }

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
    /// `changed` is what the renderer collects between renders - passed, the
    /// way the renderer passes it on every path, by a test that wrote a state
    /// some view read: a composed view is carried where nothing it read moved.
    @discardableResult
    func render(_ tree: Node, changed: Set<ObjectIdentifier> = []) -> HostPatch {
        let result = differ.reconcile(rendered, with: tree, changed: changed)
        rendered = result.node
        return result.patch
    }

    /// The walk a write takes when every cause named the state it wrote -
    /// nothing is built afresh, and only the views whose reads moved are
    /// described again. What the renderer takes for an ordinary write.
    @discardableResult
    func revisit(changed: Set<ObjectIdentifier>) -> HostPatch {
        let result = differ.revisit(rendered!, changed: changed)
        rendered = result.node
        return result.patch
    }

    /// How many times each composed view's element has been described, by the
    /// view's own NAME - what says which views a write actually rebuilt.
    ///
    /// By the name alone, because a qualified name says more than the name in
    /// two ways that both move: a type declared `private` in a file carries
    /// the file's ADDRESS - `GalleryUI.(unknown context at $11132db3c).Caption`
    /// - and a GENERIC one carries its arguments, dots and all
    /// - `StateUI.GalleryView<Swift.Array<GalleryUI.SampleGroup>, Swift.String>`,
    /// whose last dotted part is `String>`. So the arguments are cut off first
    /// and the last part of what is left is the name.
    var builds: [String: Int] {
        var counted: [String: Int] = [:]

        func walk(_ node: RenderedNode) {
            for view in node.views {
                let bare = view.type.prefix { $0 != "<" }
                let name = String(bare.split(separator: ".").last ?? "")
                counted[name] = max(counted[name] ?? 0, node.builds)
            }

            node.children.forEach(walk)
        }

        rendered.map(walk)
        return counted
    }

    /// The closure an id refers to - the DIFFER's own, whose assigned controls
    /// the render filled. A closure walked off a freshly built tree is a
    /// different one: every build makes new values, and an aim is
    /// filled where the tree was rendered.
    func handler(_ id: Int) -> EventHandler? {
        differ.handler(id)
    }

    /// Resolves a handler id carried by the typed host contract.
    func handler(_ id: Int32) -> EventHandler? {
        handler(Int(id))
    }

    /// Runs the closure an id refers to, the way a dispatched event does.
    @discardableResult
    func fire(_ id: Int, with payload: [PropValue] = []) -> Bool {
        guard let handler = differ.handler(id) else { return false }

        EventBuffer.current = payload
        Renderer.shared.start(handler)
        return true
    }

    /// Runs a handler id carried by the typed host contract.
    @discardableResult
    func fire(_ id: Int32, with payload: [PropValue] = []) -> Bool {
        fire(Int(id), with: payload)
    }
}

/// The `tapped` closure on the tab captioned `title`, wherever it is.
///
/// A tab is a caption over a rule with a tap on the pair, so the node that
/// answers is the one holding a Label that says so - see Gallery/Views/Tabs.swift.
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
    private func catalog(
        _ nav: Navigation = Place().nav,
        bar: TitleBarState = TitleBarState()
    ) -> Catalog {
        Catalog(nav: nav, style: SessionStyle(), bar: bar, log: WindowLog())
    }

    /// The gallery's window over a given place - which is where the arrangement
    /// is declared, so this is what a test asks for a detail page.
    private func window(
        _ nav: Navigation,
        bar: TitleBarState = TitleBarState()
    ) -> MainWindow {
        MainWindow(catalog: catalog(nav, bar: bar),
                   nav: nav,
                   style: SessionStyle(),
                   log: WindowLog(),
                   bar: bar)
    }

    /// A window as the host is first told about it: registered as an
    /// application of one window and rendered as a complete typed host patch -
    /// which is where what `.onCreated` writes into a session lands: the title
    /// bar, the modal stack, every page's title.
    private func firstPatch(_ window: MainWindow) -> HostPatch {
        Scenes.shared.reset()
        Renderer.shared.clearInvalidation()
        Renderer.shared.setApplication(OneWindow(window: window))

        return StateUIHost.render(baseline: 0).root
            .children[0].children[0]
    }

    /// A property of a typed host patch.
    private func prop(_ node: HostPatch, _ key: Prop) -> HostValue? {
        node.properties[key]
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

        // The samples about desktop chrome: the window's own title bar and a
        // pointer-oriented context menu.
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

            // The catalog asks for the runtime PNG name produced from the SVG
            // source. Each icon has a dark twin because one fill cannot remain
            // legible on both surfaces.
            XCTAssertTrue(group.icon.file.hasSuffix(".png"), "\(group.title): \(group.icon.file)")
            XCTAssertEqual(group.icon.dark, group.icon.file.replacingOccurrences(
                of: ".png", with: "_dark.png"), "\(group.title) has no dark twin")

            XCTAssertTrue(routes.insert(group.route).inserted,
                          "two groups answer to //\(group.route)")
        }
    }

    /// A page names its sections by place: "Example", "Notes" and "In Swift"
    /// for a sample of one example, and the same three numbered for a sample
    /// of several - which is also what the tabs of a held one say, beside
    /// "In Code".
    func testEveryExampleIsNamedByItsPlace() throws {
        let one = try XCTUnwrap(catalog().sample(id: ButtonSample.id))
        let two = try XCTUnwrap(catalog().sample(id: WebViewSample.id))
        let first = one.headings(of: 0)
        let second = two.headings(of: 1)

        XCTAssertEqual([first.example, first.notes, first.code], ["Example", "Notes", "In Swift"])
        XCTAssertEqual(
            [second.example, second.notes, second.code],
            ["Example 2", "Example 2 Notes", "Example 2 in Swift"])
        XCTAssertEqual(two.tabs.map(two.caption(of:)), ["Example 1", "Example 2", "In Code"])
    }

    /// A scrolling page shows each example, then its notes, then its Swift.
    /// The notes sit in no scroller of their own and a listing moves only
    /// across, so the page's scroller is the one thing that moves down.
    func testAScrollingPageShowsEachExampleThenItsNotesThenItsSwift() throws {
        let sample = try XCTUnwrap(catalog().sample(id: TwoLayersSample.id))
        let page = SamplePage(sample: sample, nav: Place().nav).body.built

        XCTAssertEqual(headings(in: page), [
            "Example 1", "Example 1 Notes", "Example 1 in Swift",
            "Example 2", "Example 2 Notes", "Example 2 in Swift",
        ])
        XCTAssertEqual(verticalScrollers(in: page), 1, "a scroller inside the page's scroller")
    }

    /// A held sample's code tab is one scroller: each example's notes, then
    /// its Swift, in turn - the notes in no scroller of their own.
    func testAHeldSamplesCodeTabGivesEachExamplesNotesThenItsSwift() throws {
        let sample = try XCTUnwrap(catalog().sample(id: WebViewSample.id))
        let tab = SampleTabPage(sample: sample, tab: .code, nav: Place().nav).body.built

        XCTAssertEqual(headings(in: tab), [
            "Example 1 Notes", "Example 1 in Swift",
            "Example 2 Notes", "Example 2 in Swift",
        ])
        XCTAssertEqual(verticalScrollers(in: tab), 1, "a scroller inside the tab's scroller")
    }

    /// A listing is one example's Swift, whole. Nothing cuts it into sections
    /// under headings of its own: a second thing to show is a second example.
    func testNoListingIsCutIntoSections() {
        for group in catalog().groups {
            for sample in group.samples {
                for example in sample.examples {
                    let marked = example.code.split(separator: "\n").contains {
                        $0.trimmingCharacters(in: .whitespaces).hasPrefix("// -- ")
                    }

                    XCTAssertFalse(marked, "\(sample.id) cuts a listing with a `// -- ` marker")
                }
            }
        }
    }

    /// A code listing owns only horizontal overflow. The sample page owns its
    /// vertical viewport, including a wheel gesture made above the listing.
    func testACodeBlockScrollsOnlyAcrossThePage() {
        let block = CodeBlock("let value = aVeryLongExpression()").body.built
        var scrollers: [Node] = []

        func walk(_ node: Node) {
            let node = node.built
            if node.type == "ScrollView" { scrollers.append(node) }
            node.children.forEach(walk)
        }

        walk(block)

        XCTAssertEqual(scrollers.count, 1)
        XCTAssertEqual(
            scrollers.first?.props["orientation"],
            .enumeration(ScrollOrientation.horizontal.rawValue))
        XCTAssertEqual(
            scrollers.first?.props["verticalScrollBarVisibility"],
            .enumeration(ScrollBarVisibility.never.rawValue))
        XCTAssertNil(scrollers.first?.props["horizontalScrollBarVisibility"])
    }

    /// A sample with no summary or no code is half-written, and looks finished.
    func testEverySampleSaysWhatItIsAndHowItIsWritten() {
        for group in catalog().groups {
            for sample in group.samples {
                XCTAssertFalse(sample.title.isEmpty, "\(sample.id) has no title")
                XCTAssertFalse(sample.summary.isEmpty, "\(sample.id) has no summary")
                XCTAssertFalse(sample.examples.isEmpty, "\(sample.id) shows no example")

                // Every example is a view like any other, has to describe
                // itself without being on a page, and shows the code that
                // wrote it.
                for (index, example) in sample.examples.enumerated() {
                    XCTAssertFalse(example.code.isEmpty, "\(sample.id) example \(index + 1) shows no code")
                    XCTAssertFalse(example.view.body.built.type.name.isEmpty)
                }
            }
        }
    }

    /// The code beside an example is REAL code, not a sketch of one.
    ///
    /// What a reader sees under "In Swift" is the example's own view code with
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
    /// the placement comes along and the container does not, so the pasted
    /// example does not describe the layout it claims to show.
    func testEverySamplesCodeShowsTheGridItPlacesChildrenIn() {
        let placements = ["gridRow(", "gridColumn(", "gridRowSpan(", "gridColumnSpan("]

        for group in catalog().groups {
            for sample in group.samples {
                for code in sample.examples.map(\.code)
                where placements.contains(where: { code.contains(".\($0)") }) {
                    XCTAssertTrue(
                        code.contains("Grid {") || code.contains("Grid("),
                        "\(sample.id) places a child with .gridRow or .gridColumn and shows no "
                        + "Grid around it - pasted back, that does not compile")
                }
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
                for code in sample.examples.map({ stripComments(from: $0.code) }) {
                    for name in bareProjections(in: code) {
                        XCTAssertTrue(
                            code.contains("var \(name)") || code.contains("let \(name)"),
                            "\(sample.id) lends $\(name) and never declares it - pasted back, "
                            + "that does not compile")
                    }
                }
            }
        }
    }

    /// A READING IS TAKEN WHERE THE REBUILD IS, AND THE LISTING SHOWS IT -
    /// the gallery's own rule.
    ///
    /// `DebugInfoLabel()` answers about the closure it is WRITTEN in, so where
    /// it sits is the whole of what it measures: one inside a container's
    /// THE GALLERY CARRIES ITS SEMANTICS AND ITS LISTINGS DO NOT.
    ///
    /// Every control the gallery hands a reader says what it is - so a screen
    /// reader has something to read and a script, a test or an agent has
    /// something to ask for by name instead of a coordinate off a picture.
    /// None of it belongs in a sample's `code`: a listing is there to show how
    /// the control is WRITTEN, and three lines of accessibility per control
    /// would bury the one line the sample is about.
    ///
    /// The exception is the sample that is ABOUT semantics, where the
    /// modifiers are the subject and leaving them out would show nothing.
    func testNoSamplesListingCarriesItsSemantics() {
        let modifiers = [
            ".automationId(", ".semanticDescription(",
            ".semanticHint(", ".semanticHeadingLevel(",
        ]

        for group in catalog().groups {
            for sample in group.samples where sample.id != SemanticsSample.id {
                for modifier in modifiers where sample.code.contains(modifier) {
                    XCTFail("""
                        \(sample.id) shows `\(modifier)` in its listing.

                        What a view says about itself is written in the gallery \
                        and left out of the snippet: the listing is about the \
                        control, and only the Semantics sample is about this.
                        """)
                }
            }
        }
    }

    /// braces counts that container, and one outside them counts a description
    /// that a read deeper down never reaches. A reader looking at the example
    /// therefore has to be able to see the place, which is what the `code`
    /// listing is - so the two are held to the same number here.
    ///
    /// Nothing adds a reading from outside. A count the PAGE took would stand
    /// still while a sample's state moved, and one a wrapper took would name
    /// every piece of the sample's state through itself; both were tried.
    func testEveryReadingASampleTakesIsShownInItsListing() throws {
        let samples = catalog().groups.flatMap(\.samples)

        for (path, text) in try gallerySources() {
            guard let id = declaredId(in: text),
                  let sample = samples.first(where: { $0.id == id }) else { continue }

            // The listing is written INSIDE the file, so what the file says
            // less what the listing says is what the example actually takes.
            let shown = occurrences(of: "DebugInfoLabel()", in: sample.code)
            let taken = occurrences(of: "DebugInfoLabel()", in: text) - shown

            XCTAssertEqual(
                taken, shown,
                "\(path) takes \(taken) build readings and shows \(shown) in its code - "
                + "a reading whose place a reader cannot see says nothing about what "
                + "is being measured")
        }
    }

    /// An example that FILLS reaches the cell it is given.
    ///
    /// A held page hands its example a star row, and everything between that
    /// row and the example has to pass the height on. A STACK does not: it
    /// gives a child the length the child asks for, and a scroller asked how
    /// long it wants to be answers with the whole of its content - so a list
    /// under one is laid out as long as its run, spills off the page and has
    /// nothing left to scroll. Measured on Mac Catalyst: a thousand-row list
    /// reported a viewport of 37061 points against a run of 37000 and
    /// described every row of it, and a hundred thousand rows exhausted the
    /// renderer's child count. What carries such an example
    /// is therefore a GRID, whose one implicit row IS the cell.
    func testAFillingExampleRidesAGridRatherThanAStack() throws {
        let page = SampleTabPage(sample: Sample(Filling()), tab: .example(0), nav: Place().nav).body
        var carriers: [String] = []

        // The chain from the box the page draws around a part down to the
        // scroller inside it: a stack anywhere along it is the defect.
        func walk(_ node: Node, within: [String]?) {
            let node = node.built
            let name = node.type.name
            let inside = within ?? (name == "Border" ? [] : nil)

            if name == "ScrollView", let inside {
                carriers = inside
            }

            node.children.forEach { walk($0, within: inside.map { $0 + [name] }) }
        }

        walk(page, within: nil)

        XCTAssertFalse(carriers.isEmpty, "the page draws no box around the example")

        XCTAssertFalse(
            carriers.contains { $0 == "VStack" || $0 == "HStack" },
            "a filling example hangs under \(carriers) - a stack gives a child the "
            + "height it asks for, and a scroller asks for the whole of its content")
    }

    /// A HELD example shows no paragraphs: its words are declared as `notes`.
    ///
    /// A page that cannot scroll gives the example and the words ONE screen
    /// between them, so an explanation written as the example's last row is
    /// taken out of the example - measured on an iPhone SE, two paragraphs left
    /// a list three rows. Declared as `notes` the same words sit on the code
    /// tab, in a scroller that has room for them.
    ///
    /// What tells the two apart is LENGTH. A held example says short things -
    /// a caption on a box, a reading it writes as it runs, "Tapped 3 time(s)" -
    /// and the longest of them across the whole gallery is little more than
    /// half this bound, while a paragraph runs to three or four times it.
    func testAHeldExamplePutsItsParagraphsInItsNotes() {
        // The longest a held example's text may be.
        let bound = 100

        for group in catalog().groups {
            for sample in group.samples where !sample.scrolls {
                for example in sample.examples {
                    for said in shownTexts(in: example.view.body.built) where said.count > bound {
                        XCTFail("\(sample.id) explains itself inside the example - "
                                + "\"\(said.prefix(60))...\" - and a held page has one "
                                + "screen for the example and the words together, so the "
                                + "words belong in `notes`")
                    }
                }
            }
        }
    }

    /// A sample whose examples hold the page still is shown as tabs - the
    /// window's own - one per example, then the code. A sample that scrolls
    /// is one page.
    func testAHeldSampleIsShownAsTabs() throws {
        let held = try XCTUnwrap(catalog().groups.first { $0.route == "gestures" }?.samples.first)
        let scrolling = try XCTUnwrap(catalog().groups.flatMap(\.samples).first { $0.scrolls })

        XCTAssertTrue(SamplePage.shown(held, nav: Place().nav) is TabbedView)
        XCTAssertTrue(SamplePage.shown(scrolling, nav: Place().nav) is SamplePage)
        XCTAssertEqual(held.tabs, [.example(0), .code])
        XCTAssertEqual(held.tabs.map(held.caption(of:)), ["Example", "In Code"])
    }

    // MARK: - The arrangement built from it

    /// The gallery opens on its run of group cards: the home page is the root
    /// of the main stack in the home section. How a card opens its group is
    /// `testTheHomePagesGalleryAnswersATap`.
    func testTheGalleryOpensOnItsRunOfGroupCards() {
        let place = Place()

        XCTAssertEqual(place.section.wrappedValue, .home)
        XCTAssertTrue(window(place.nav).root() is HomePage)
    }

    /// The gallery is a menu over a stack, and both halves are pages.
    ///
    /// Every structural claim the rest of this app rests on: the flyout holds
    /// two children wearing the identity of their halves, the pane has a native
    /// title, and the detail is a stack that opens on its root alone.
    func testTheWindowIsAMenuOverAStack() throws {
        let window = GalleryScene().windows.main.body.built

        XCTAssertEqual(window.type, "Window")

        let flyout = try XCTUnwrap(window.children.first)

        XCTAssertEqual(flyout.type, "SplitView")
        XCTAssertEqual(flyout.props["isSidebarVisible"], .bool(false))
        XCTAssertNotNil(flyout.events["isSidebarVisibleChanged"],
                        "a native presentation change would not reach the binding")

        XCTAssertEqual(flyout.children.compactMap { $0.id }, ["sidebar", "detail"])

        let pane = try XCTUnwrap(flyout.children.first).built

        XCTAssertEqual(pane.type, "Page")

        // The pane's title is its session's, written as the pane comes in, so
        // it is in the complete patch that brings the pane to the host.
        let first = firstPatch(self.window(Place().nav))
        let shownPane = try XCTUnwrap(first.children.first?.children.first)

        XCTAssertEqual(shownPane.type, "Page")
        XCTAssertNotNil(prop(shownPane, .title), "the flyout pane has no native title")

        let detail = try XCTUnwrap(flyout.children.last).built

        XCTAssertEqual(detail.type, "NavigationStack")
        XCTAssertNotNil(detail.props["barBackgroundColor"], "the bar is left to the platform")
        XCTAssertNotNil(detail.props["barTextColor"])
        XCTAssertNotNil(detail.events["popped"], "a back gesture would not reach the path")
        XCTAssertEqual(detail.children.count, 1, "the stack opens on its root alone")
    }

    /// The gallery's own window exercises the complete native size and
    /// operation policy while leaving placement to the platform.
    func testTheMainWindowCarriesItsNativePropertyPolicy() {
        let shown = firstPatch(window(Place().nav))

        XCTAssertEqual(prop(shown, .title), .string("StateUI Gallery"))
        XCTAssertEqual(prop(shown, .width), .number(1_100))
        XCTAssertEqual(prop(shown, .height), .number(800))
        XCTAssertEqual(prop(shown, .minimumWidth), .number(700))
        XCTAssertEqual(prop(shown, .minimumHeight), .number(500))
        XCTAssertEqual(prop(shown, .maximumWidth), .number(1_600))
        XCTAssertEqual(prop(shown, .maximumHeight), .number(1_200))
        XCTAssertEqual(prop(shown, .isMaximizable), .bool(true))
        XCTAssertEqual(prop(shown, .isMinimizable), .bool(true))
        XCTAssertNil(prop(shown, .x))
        XCTAssertNil(prop(shown, .y))
    }

    /// The live window exercises the complete authored title-area value group
    /// and retains interactive content as identified slot children.
    func testTheWindowCarriesTheCompleteTitleBarContract() throws {
        StandardEnvironment.device.idiom = .desktop
        defer { StandardEnvironment.device.idiom = .unknown }

        let state = TitleBarState()
        state.subtitle = "Shared"
        state.showsSurprise = true
        let shown = firstPatch(window(Place().nav, bar: state))
        let bar = try XCTUnwrap(shown.children.first { $0.type == "TitleBar" })

        XCTAssertEqual(prop(bar, .title), .string("StateUI"))
        XCTAssertEqual(prop(bar, .subtitle), .string("Shared"))
        XCTAssertEqual(prop(bar, .icon), .string("stateui_mark.png"))
        XCTAssertNotNil(prop(bar, .foregroundColor))
        XCTAssertNotNil(prop(bar, .backgroundColor))
        XCTAssertNil(
            bar.children.first { $0.type == "LeadingContent" },
            "the flyout's own native toggle opens the menu; the bar authors no second one")
        let trailing = try XCTUnwrap(
            bar.children.first { $0.type == "TrailingContent" })
        XCTAssertEqual(buttons(in: trailing).count, 1)
    }

    /// And a SECOND list beside the page: what is presented over all of it,
    /// which is the window's rather than any page's.
    func testTheWindowCarriesAModalStack() throws {
        // The stack is the window's SESSION's, written as the window comes in -
        // so it is read off the message that brings the window.
        let shown = firstPatch(window(Place().nav))

        let presented = try XCTUnwrap(shown.children.first { $0.type == "ModalStack" })

        XCTAssertEqual(presented.children.count, 0, "the gallery opens with nothing over it")
        XCTAssertNotNil(shown.events?[.modalPopped],
                        "a sheet the reader drags down would not reach the array")
    }

    /// Presenting and closing are the array growing and shrinking - the same
    /// two moves a navigation path has, one level up.
    func testPresentingAndClosingAreTheArray() {
        let place = Place()

        place.nav.present(.page)
        XCTAssertEqual(place.sheets.wrappedValue, [.page])

        place.nav.present(.page)
        XCTAssertEqual(place.sheets.wrappedValue.count, 2, "a sheet may present a sheet")

        place.nav.dismiss()
        XCTAssertEqual(place.sheets.wrappedValue, [.page])

        place.nav.dismiss()
        XCTAssertTrue(place.sheets.wrappedValue.isEmpty)

        place.nav.dismiss()
        XCTAssertTrue(place.sheets.wrappedValue.isEmpty, "and closing nothing is nothing")
    }

    /// A gallery is a SCENE: its main window, and beside it the Fonts and
    /// Colours windows and the inspector - one window of each kind - and a
    /// swatch window per number, all opened by the gallery and never by *File ▸
    /// New Window*, which opens a gallery.
    func testAGalleryIsASceneWithItsToolsBesideIt() {
        let windows = GalleryScene().windows

        XCTAssertEqual(windows.groups.map(\.type), [.fonts, .colours, .debugInspector, .swatch])
        XCTAssertEqual(windows.groups.filter { $0.valueType != nil }.map(\.type), [.swatch])
        XCTAssertTrue(windows.main is MainWindow)
    }

    /// The whole application is that scene - as many galleries as the reader
    /// opens, and nothing else.
    func testTheApplicationIsItsGallery() {
        XCTAssertTrue(GalleryApp().scene is GalleryScene)
    }

    /// The menu lists Home, every group, and the one row that performs an act.
    ///
    /// A Shell built these rows from items it held; this walks the page the app
    /// wrote, which is what the reader taps.
    func testTheMenuHasARowForHomeEveryGroupAndTheActAtTheEnd() {
        let catalog = catalog()
        let menu = MenuPage(catalog: catalog, nav: Place().nav,
                            log: WindowLog(), listsHiddenRow: false)

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
                     log: WindowLog(), listsHiddenRow: lists)
        }

        XCTAssertFalse(rowTitles(in: menu(false).body).contains("Not in the list"))
        XCTAssertTrue(rowTitles(in: menu(true).body).contains("Not in the list"))

        // And the section itself needs no row: this is what the sample's
        // "Go there anyway" button does.
        place.nav.open(.hidden)
        XCTAssertEqual(place.section.wrappedValue, .hidden)
    }

    /// Choosing a section is three writes and no await: the section, its new
    /// path, and the menu closing behind it. Navigation remains application
    /// state rather than a host command.
    func testChoosingASectionMovesTheApplicationAndClosesTheMenu() throws {
        let place = Place()
        place.path.wrappedValue = [.sample("grid")]
        place.menu.wrappedValue = true

        let menu = MenuPage(catalog: catalog(place.nav), nav: place.nav,
                            log: WindowLog(), listsHiddenRow: false)

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

    /// The way home is one assignment to the path the application owns.
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
    /// are the STACK's - measured, and where the first live run of TabbedView
    /// showed no icons at all.
    func testTheTabsSectionIsATabbedViewWithAStackInsideIt() throws {
        let place = Place()
        place.section.wrappedValue = .tabs

        let detail = window(place.nav).detail().body

        XCTAssertEqual(detail.type, "TabbedView")
        XCTAssertEqual(detail.props["currentPage"], .number(0))
        XCTAssertNotNil(detail.events["currentPageChanged"],
                        "a tab tapped - or swiped, on Android - would not reach the binding")
        XCTAssertEqual(detail.children.count, DemoTab.opening.count)

        let stack = try XCTUnwrap(detail.children.first)

        XCTAssertEqual(stack.type, "NavigationStack")
        XCTAssertEqual(stack.props["title"], .string("Stack"))
        XCTAssertNotNil(stack.props["iconImageSource"], "a tab with no picture")

        // A written page's caption and picture are its SESSION's, written as
        // it comes in - so they are read off the message that brings it.
        let shown = firstPatch(window(place.nav))
        let tabbed = try XCTUnwrap(shown.children.first?.children.last)
        let second = try XCTUnwrap(tabbed.children.last)

        XCTAssertEqual(tabbed.type, "TabbedView")
        XCTAssertEqual(prop(second, .title), .string("Second"))
        XCTAssertNotNil(prop(second, .iconImageSource))
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

        let tabsPath = place.tabsPath

        let detail = window(place.nav).detail().body

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

        let detail = window(place.nav).detail().body

        for (index, child) in detail.children.enumerated() {
            // The first tab is a stack, so the page to read is its root.
            let page = child.type == "NavigationStack"
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

        for group in catalog.groups {
            try assertEveryCardIsTappable(in: GroupPage(group: group, nav: Place().nav).body.built,
                                          expecting: group.samples.count)
        }
    }

    /// The home page's run of cards is sized by the CYCLE, not by a render.
    ///
    /// The run is given what the page's other rows can spare, and what they can
    /// spare is not known until the page has been laid out - so this page is
    /// arranged from its own measurement, and a measurement settles over
    /// several passes. DESCRIBED, that is a render per pass with the whole page
    /// rebuilt inside each one, and everything standing under the run riding
    /// every step. DRIVEN, the host wears the answer on its own frames and the
    /// tree says nothing at all.
    ///
    /// What holds the second is registrations rather than values: the page
    /// feeds its room onto a number, an engine over that number answers the
    /// run's height, and the entrance is a number too - so even coming in
    /// costs no render.
    /// A CARD CROSSED DESCRIBES THE WORDS UNDER THE RUN AND NOTHING ELSE.
    ///
    /// The page holds the heading, the run of cards and the footer; what
    /// follows the position is the caption and the two arrows. Read in the
    /// PAGE's own closure - which is where they were until 2026-09-11 - the
    /// position made the page its reader, so every card crossed described the
    /// page, and with it the gallery, its scroller and everything they are
    /// made of. Each of the two is a view of its own now, so the read is
    /// theirs.
    ///
    /// It is the user's own rule, one level in: whoever reads a value is
    /// described again when it changes, so what reads it should be the
    /// smallest view that can.
    func testACardCrossedDescribesTheCaptionAndNotThePage() throws {
        // The arrows are a desktop's, a finger having the run itself.
        StandardEnvironment.device.idiom = .desktop
        defer { StandardEnvironment.device.idiom = .unknown }

        Renderer.shared.clearInvalidation()

        let renders = Renders()
        let page = HomePage(catalog: catalog(), nav: Place().nav)

        let first = renders.render(page.body)
        let before = renders.builds

        // What the reader does: the arrow under the run, which writes the
        // position through the binding the page lends it.
        let forward = try XCTUnwrap(
            buttons(in: first).first { $0.props[.text] == .string("›") })
        XCTAssertTrue(renders.fire(try XCTUnwrap(forward.events?[.clicked])))

        renders.revisit(changed: Renderer.shared.pendingChanges)
        let after = renders.builds

        // NAMED, OR THE TWO COMPARISONS BELOW ARE nil AGAINST nil - which is a
        // green test about nothing, and how this one first passed.
        XCTAssertNotNil(before["HomePage"])
        XCTAssertNotNil(before["Caption"])
        XCTAssertNotNil(before["GalleryView"])

        XCTAssertEqual(
            after["Caption"], (before["Caption"] ?? 0) + 1,
            "the caption reads the position, so it is the view built again")
        XCTAssertEqual(
            after["GalleryView"], before["GalleryView"],
            """
            The run of cards was described for a card crossed. It holds its \
            items behind a class and takes closures, so it can never be \
            carried - which is exactly why nothing above it may read the \
            position.
            """)
        XCTAssertEqual(
            after["HomePage"], before["HomePage"],
            """
            The page was described for a card crossed. Whatever reads the \
            position belongs in a view of its own - the caption and the arrows \
            are those views.
            """)
    }

    /// Every button in a patch, wherever it sits.
    private func buttons(in patch: HostPatch) -> [HostPatch] {
        var found: [HostPatch] = []

        func walk(_ patch: HostPatch) {
            if patch.type == .button { found.append(patch) }
            patch.children.forEach(walk)
        }

        walk(patch)
        return found
    }

    func testTheHomePageIsSizedByTheCycleRatherThanByARender() throws {
        let page = HomePage(catalog: catalog(), nav: Place().nav).body.built
        var heights: [String] = []
        var rooms: [String] = []
        var fades: [String] = []
        var engines = 0

        func walk(_ node: Node) {
            if node.driven[.heightRequest] != nil { heights.append(node.type.name) }
            if node.driven[.frame] != nil { rooms.append(node.type.name) }
            if node.driven[.opacity] != nil { fades.append(node.type.name) }

            engines += node.engines.count

            node.children.forEach(walk)
        }

        walk(page)

        // ONE driven height, and it is the run's. Every other size on the page
        // is stated in the tree, which is what a size nobody measured is.
        XCTAssertEqual(heights.count, 1,
                       "the run's height is described rather than driven")

        // TWO rooms: the page's own, which that height is arithmetic over, and
        // the gallery's, which its cards are placed in.
        XCTAssertEqual(rooms, ["Grid", "AbsoluteLayout"],
                       "the page and its run are measured onto numbers")

        // And the entrance is the third number - so the page waits for its room
        // to settle and then comes in, with nothing built for either.
        XCTAssertEqual(fades.count, 1,
                       "the page comes in through a render rather than through the cycle")

        XCTAssertEqual(engines, 3,
                       "the page and its run of cards keep three engines between them")
    }

    /// And the home page's groups answer one, which is the gallery's.
    ///
    /// A `GalleryView` is swiped to choose and tapped to open, so there is ONE
    /// handler however many groups there are - inside the scroller lying over
    /// the cards, which is the only thing here a finger can reach.
    func testTheHomePagesGalleryAnswersATap() throws {
        let page = HomePage(catalog: catalog(), nav: Place().nav).body.built
        var carriers: [String] = []

        func walk(_ node: Node) {
            if node.events["tapped"] != nil { carriers.append(node.type.name) }
            node.children.forEach(walk)
        }

        walk(page)

        XCTAssertEqual(carriers, ["BoxView"],
                       "the home page's gallery is opened by a tap on the run")
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
    /// arrives at all. The page therefore holds the example still and scrolls
    /// the code instead, which is the part a reader needs to move.
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

            /// What a node says, whether that is one string or a set of runs.
            ///
            /// A `CodeBlock` colours its snippet with spans under one formatted
            /// label, so the visible text is what those runs spell together.
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
                    codeScrolls = codeScrolls || sample.examples.contains { $0.code == shownText(node) }
                }

                node.children.forEach { walk($0, scrolled: scrolled) }
            }

            // BOTH tabs, because the page shows one at a time and each has to
            // hold on its own: the example must never be under a scroller, and
            // the code must always be under one.
            XCTAssertTrue(
                sample.tabs.contains(.example(0)) && sample.tabs.contains(.code),
                "\(sample.id) does not offer the example and the code")

            for tab in [SampleTab.example(0), .code] {
                walk(SampleTabPage(sample: sample, tab: tab, nav: Place().nav).body.built, scrolled: false)
            }
            XCTAssertGreaterThan(found, 0, "\(sample.id) is a gesture sample with no gesture on it")
            XCTAssertEqual(caught, [], "\(sample.id) would lose \(caught) to the page's scroller")
            XCTAssertTrue(codeScrolls, "\(sample.id) shows its code with no way to scroll it")
        }
    }

    /// The pinch sample scales a CHILD of the view the recognizer is on.
    ///
    /// A view that transforms itself while a gesture is running can cancel its
    /// native recognizer. The gesture surface and transformed surface therefore
    /// remain separate.
    func testThePinchSampleDoesNotScaleTheViewItsGestureIsOn() throws {
        let sample = try XCTUnwrap(catalog().sample(id: "pinch"))

        var pinched: [Node] = []
        var scaled: [Node] = []

        func walk(_ node: Node) {
            if node.events["pinchUpdated"] != nil { pinched.append(node) }
            if node.props["scale"] != nil { scaled.append(node) }
            node.children.forEach(walk)
        }

        for example in sample.examples {
            walk(example.view.body.built)
        }

        XCTAssertEqual(pinched.count, 1)
        XCTAssertEqual(scaled.count, 1)

        XCTAssertNil(pinched.first?.props["scale"],
                     "the recognizer is on the view it transforms, which is what stops a pinch")
        XCTAssertNil(scaled.first?.events["pinchUpdated"])
    }

    /// The pinch works on a platform that never sends `.started`.
    ///
    /// A native trackpad magnification may arrive as `.running` followed by
    /// `.completed`, with no `.started`. Multiplying by each report's change
    /// keeps the interaction independent of that optional phase.
    func testThePinchSampleDoesNotWaitForAStatusThatMayNeverCome() throws {
        // The sample owns its state now, so the test goes through a render the
        // way the app does: fire the handler the host reports, then read the
        // scale that lands on the tree.
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

        let second = renders.render(PinchSample().body, changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(try XCTUnwrap(number("scale", in: second)), 1.02, accuracy: 0.0001,
                       "the scale did not follow a pinch that never said .started")

        // And a second gesture goes on from where the first left off.
        renders.fire(pinchUpdated, with: [
            .enumeration(GestureStatus.running.rawValue), .number(1.02), .numbers([0.5, 0.45]),
        ])

        let third = renders.render(PinchSample().body, changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(try XCTUnwrap(number("scale", in: third)), 1.0404, accuracy: 0.0001)
    }

    /// The id a patch assigned to an event, wherever in the tree it landed.
    private func eventId(_ event: Event, in patch: HostPatch) -> Int32? {
        if let id = patch.events?[event] { return id }

        for child in patch.children {
            if let id = eventId(event, in: child) { return id }
        }

        return nil
    }

    /// The first value a patch carries for a property, wherever it landed.
    private func number(_ prop: Prop, in patch: HostPatch) -> Double? {
        if case .number(let value)? = patch.props[prop] { return value }

        for child in patch.children {
            if let value = number(prop, in: child) { return value }
        }

        return nil
    }

}

/// The gallery's samples, as text, walked rather than listed - the same rule
/// the build follows, so a sample added in a new group is read without
/// anything being told about it.
private func gallerySources() throws -> [(path: String, text: String)] {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()    // GalleryTests
        .deletingLastPathComponent()    // Tests
        .deletingLastPathComponent()    // Gallery
        .deletingLastPathComponent()    // apps
        .deletingLastPathComponent()    // the repository
        .appendingPathComponent("apps/Gallery/Sources/Samples")

    guard let walk = FileManager.default.enumerator(atPath: root.path) else { return [] }

    var found: [(path: String, text: String)] = []

    for case let name as String in walk where name.hasSuffix(".swift") {
        let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
        found.append((path: name.replacingOccurrences(of: "\\", with: "/"), text: text))
    }

    return found.sorted { $0.path < $1.path }
}

/// The sample a source file declares, by the id it gives itself - which is
/// what pairs a file with the catalog entry built from it.
private func declaredId(in text: String) -> String? {
    guard let range = text.range(of: "static let id = \"") else { return nil }

    let rest = text[range.upperBound...]

    guard let end = rest.firstIndex(of: "\"") else { return nil }

    return String(rest[..<end])
}

/// How many times one string stands in another.
private func occurrences(of needle: String, in text: String) -> Int {
    var rest = Substring(text)
    var count = 0

    while let range = rest.range(of: needle) {
        count += 1
        rest = rest[range.upperBound...]
    }

    return count
}

/// An application of one window - what a test registers to have the renderer's
/// own first message about that window.
private struct OneWindow: Application {
    let window: MainWindow

    var scene: any Scene { window }
}
