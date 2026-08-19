// What every test here needs: a differ to talk to, and a way to say what came
// out of it.
//
// Foundation is fine here, and only here: a test target is never part of the
// library, and reading a file is not what the ICU rule is about.

import Foundation
import StateUIWireProbe
import XCTest
@testable import StateUI

/// The queued acts, taken and decoded - the values already apart, so a test
/// asserts on an act rather than searching bytes.
func drainedActs() -> [WireAct] {
    WireProbe.decode(Renderer.shared.takeCommandsWire())
}

/// A differ and the tree it last produced, so a test can render twice and look
/// at what the second render had to say.
final class Renders {
    private let differ = Differ()
    private var rendered: RenderedNode?

    /// Renders a tree and returns what would have been sent.
    ///
    /// `changed` is what the renderer collects from `stateChanged` between
    /// renders: the storages whose state moved. It reaches the differ's memo
    /// skip, which walks a carried subtree for views whose state changed
    /// rather than carrying it blindly.
    ///
    /// `styles` is the application's sheet, which the differ resolves every
    /// element against - passed on each render, exactly as the renderer reads
    /// it on each build, so a test can move one and watch what follows.
    @discardableResult
    func render(
        _ tree: Node,
        styles: StyleSheet? = nil,
        changed: Set<ObjectIdentifier> = []
    ) -> Patch {
        let offered = offerFlights()
        let result = differ.reconcile(rendered, with: tree, styles: styles, changed: changed)
        rendered = result.node
        settleFlights(offered)
        runFired()
        return result.patch
    }

    /// Renders with NO fresh tree at all - the clean walk `Renderer.renderWire`
    /// takes when every cause of the render named the state it wrote. Only the
    /// views whose recorded reads intersect `changed` are built again.
    @discardableResult
    func revisit(changed: Set<ObjectIdentifier>) -> Patch {
        let offered = offerFlights()
        let result = differ.revisit(rendered!, changed: changed)
        rendered = result.node
        settleFlights(offered)
        runFired()
        return result.patch
    }

    /// Renders as if the host had lost track - which is what a mismatched
    /// generation does: everything is described, against the tree this side
    /// still holds, exactly as `Renderer.renderWire` does it. Identity, state
    /// and handlers survive; only the message gets bigger.
    @discardableResult
    func renderFromScratch(_ tree: Node) -> Patch {
        let offered = offerFlights()
        let result = differ.reconcile(rendered, with: tree, describeAll: true)
        rendered = result.node
        settleFlights(offered)
        runFired()
        return result.patch
    }

    /// What `Renderer.renderWire` does around every walk: hand the differ the
    /// flights an author has started, and answer the ones the walk found
    /// nothing to fly. Mirrored here rather than reached through, for the same
    /// reason `runFired` is - a test then exercises the real registry.
    private func offerFlights() -> [FlightKey: PendingFlight] {
        let offered = Renderer.shared.offeredFlights()
        differ.flights = offered
        return offered
    }

    private func settleFlights(_ offered: [FlightKey: PendingFlight]) {
        Renderer.shared.settle(offered: offered, carried: differ.takeCarried())
    }

    /// Runs what `.onChanged` noticed, the way the real path does: queued as
    /// jobs by the render, run by the host's next drain - which here is one
    /// `stateUIRunJobs()`, exactly what `ScheduleDrain` calls.
    private func runFired() {
        for handler in differ.takeFired() {
            Renderer.shared.queue(handler)
        }

        stateUIRunJobs()
    }

    /// Runs the closure an id refers to, the way a dispatched event does.
    ///
    /// Goes through `Renderer.start`, which is what `stateui_dispatch_wire`
    /// uses, rather than calling the closure - so what a test sees is the real
    /// path, including the executor a handler resumes on. Synchronous, because
    /// that path is: a handler with no `await` in it finishes before this
    /// returns, exactly as it did when handlers could not suspend at all.
    @discardableResult
    func fire(_ id: Int, with payload: [PropValue] = []) -> Bool {
        guard let handler = differ.handler(id) else { return false }

        // What stateui_dispatch_wire does before starting the handler: the
        // payload is left where the typed handlers read it from.
        EventBuffer.current = payload
        Renderer.shared.start(handler)
        return true
    }
}

/// A control state filled BY HAND from a named element, for acts that must aim
/// without a render: what an act sends is the element's identity, and this
/// is the named kind - the wire the command fixtures pin. The differ's own
/// filling of one is ControlStateTests' business.
func named<Target>(_ name: String, _ type: Target.Type) -> ControlState<Target> {
    let state = ControlState<Target>()
    state.box.attach(.manual(name), walk: 1)
    return state
}

/// Runs whatever a resumed handler left waiting, the way the host does.
///
/// `resume()` schedules the rest of a handler rather than continuing it, and the
/// job it produces arrives a moment later - so a test that reports an act as
/// finished has to wait for it, exactly as `DrainWhenTheResumeArrives` does on
/// the C# side. Returns as soon as something ran.
@discardableResult
func settle(timeout: TimeInterval = 2) async -> Int {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        let ran = stateUIRunJobs()
        if ran > 0 { return ran }
        try? await Task.sleep(nanoseconds: 100_000)
    }

    return 0
}

/// The files both halves of the suite are checked against, and the library's
/// own sources - which two of the control tests read.
enum Fixtures {
    /// `src/Tests/fixtures`, found from this file rather than from a working
    /// directory that depends on who started the process.
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // StateUITests
            .deletingLastPathComponent()    // Tests
            .appendingPathComponent("fixtures")
    }

    /// `src/StateUI/Sources`.
    static var sources: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // StateUITests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // src
            .appendingPathComponent("StateUI")
            .appendingPathComponent("Sources")
    }

    /// The repository root, for the few checks that are about the BUILD rather
    /// than about the code - a manifest, a script.
    static var repository: URL {
        sources
            .deletingLastPathComponent()    // StateUI
            .deletingLastPathComponent()    // src
            .deletingLastPathComponent()    // the repository
    }

    static var updating: Bool {
        ProcessInfo.processInfo.environment["STATEUI_UPDATE_FIXTURES"] == "1"
    }

    /// Checks a binary message and its readable sidecar against their
    /// fixtures, or writes both when updating.
    ///
    /// `name` carries no extension - `commands/Focus` is checked against
    /// `Focus.bin`, the CONTRACT the C# side reads, and `Focus.txt`, the
    /// rendering a review diff reads. It may name a subdirectory, which is
    /// created if it is not there. Both files are compared: a sidecar that
    /// drifted from its bytes would lie to exactly the reader it exists for.
    static func check(
        _ bytes: [UInt8],
        sidecar: String,
        against name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let binary = directory.appendingPathComponent(name + ".bin")
        let text = directory.appendingPathComponent(name + ".txt")

        if updating {
            try FileManager.default.createDirectory(
                at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(bytes).write(to: binary)
            try sidecar.write(to: text, atomically: true, encoding: .utf8)
            return
        }

        let hint = """
            Either something broke, or the format changed on purpose - in which
            case run the tests again with STATEUI_UPDATE_FIXTURES=1 and commit
            the new fixtures, so the C# side is checked against them too.
            """

        XCTAssertEqual(
            Data(bytes), try Data(contentsOf: binary),
            "The bytes no longer match \(name).bin.\n\n\(hint)",
            file: file, line: line)

        XCTAssertEqual(
            sidecar, try String(contentsOf: text, encoding: .utf8),
            "The rendering no longer matches \(name).txt.\n\n\(hint)",
            file: file, line: line)
    }

    /// Every property name a source file sets, read out of the file itself.
    ///
    /// A regex over source code is a poor way to know anything, and this is the
    /// one place it earns its keep: it is a TEST reading the library next to it,
    /// and it can only ever under-report. A key it fails to see is a key nothing
    /// insists on covering - never a false failure, and never anything the
    /// library does at run time.
    ///
    /// BOTH ways a property is written, because under-reporting is exactly what
    /// went wrong: a modifier that sets two things at once cannot chain
    /// `setValue`, so it writes `props[…]` inside `modified` - and a scanner
    /// looking only for `setValue` waved it through. The sources write TOKENS
    /// since the dictionary round, and a Prop token's member spelling IS the
    /// property name, so the scan reads the member.
    /// THREE ways now, and the third was a hole this wide: a type that is not a
    /// `PropertyContainer` cannot write `setValue`, so it keeps a private
    /// `set(_:_:)` of its own - ToolbarItem, MenuBarItem and Window all do -
    /// and every property written that way was INVISIBLE to
    /// this scan. The subscript is read without a leading dot as well, so the
    /// properties a PAGE contributes (`props[.title]` on a local dictionary in
    /// Application.swift) are seen too.
    static func propertyKeys(in file: String) throws -> Set<String> {
        // COMMENTS FIRST. The doc above every modifier quotes the spellings it
        // is about, and a scan that reads them would claim a property is
        // declared because a sentence mentioned it.
        let source = try text(in: file)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.drop(while: { $0 == " " }) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")

        return Set(source.occurrences(between: "setValue(.", and: ","))
            .union(source.words(before: "set(.", upTo: ","))
            .union(source.occurrences(between: "props[.", and: "]"))
    }

    /// Every EVENT a source file subscribes - `addHandler(.scrollYChanged)`.
    ///
    /// The sibling of `propertyKeys`, and the reason it exists: a modifier
    /// whose whole body is an `addHandler` writes no property, so the modifier
    /// guard cannot see it at all. Two reached the shelf that way.
    static func handlerKeys(in file: String) throws -> Set<String> {
        let source = try text(in: file)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.drop(while: { $0 == " " }) }
            .filter { !$0.hasPrefix("//") }
            .joined(separator: "\n")

        // Character-wise, the way `nodeTypes` reads its members: the token ends
        // at the first character an identifier cannot hold. Reading up to the
        // closing parenthesis instead swallowed whole multi-line closures.
        var events: Set<String> = []
        var rest = Substring(source)

        while let found = rest.range(of: "addHandler(.") {
            rest = rest[found.upperBound...]
            let name = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }

            if !name.isEmpty { events.insert(String(name)) }
        }

        return events
    }

    /// Every MAUI type a source file describes - `Node(type: .label)`. A
    /// NodeType token's member is the type name with its first letter
    /// lowered, so the scan raises it back; the member ends at the first
    /// character an identifier cannot contain, whether a comma or the
    /// closing parenthesis follows.
    static func nodeTypes(in file: String) throws -> Set<String> {
        let source = try text(in: file)
        var types: Set<String> = []
        var rest = Substring(source)

        while let range = rest.range(of: "Node(type: .") {
            rest = rest[range.upperBound...]
            let member = rest.prefix { $0.isLetter || $0.isNumber || $0 == "`" }
            let plain = member.replacingOccurrences(of: "`", with: "")
            types.insert(plain.prefix(1).uppercased() + plain.dropFirst())
        }

        return types
    }

    /// One of the library's own source files, read as text.
    static func text(in file: String) throws -> String {
        try String(
            contentsOf: sources.appendingPathComponent("Views").appendingPathComponent(file),
            encoding: .utf8)
    }

    /// Every one of the library's sources, wherever it sits.
    ///
    /// Found by walking, not listed - the same rule the build follows, so a new
    /// subdirectory is covered without anything being told about it.
    ///
    /// The path is reported with FORWARD slashes on every platform. The walk
    /// yields `Bridge\Exports.swift` on Windows, and a caller comparing against
    /// a written path - `hasSuffix("Bridge/Exports.swift")`, which is how the
    /// one file allowed to declare `@_cdecl` is recognized - then matches
    /// nothing and names that very file as the offender. Measured 2026-08-06;
    /// the same rule the build follows for MSBuild paths, one level up.
    static func allSources() throws -> [(path: String, text: String)] {
        let root = sources
        var found: [(path: String, text: String)] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else { return [] }

        for case let name as String in walk where name.hasSuffix(".swift") {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            found.append((path: name.replacingOccurrences(of: "\\", with: "/"), text: text))
        }

        return found.sorted { $0.path < $1.path }
    }

    /// Every test source in this package, so a guard can ask whether some test
    /// names a thing. Both targets: the library's tests and the gallery's.
    static func testSources() throws -> [(path: String, text: String)] {
        var found: [(path: String, text: String)] = []

        for target in ["StateUITests", "GalleryTests"] {
            let root = repository.appendingPathComponent("src/Tests/\(target)")

            guard let walk = FileManager.default.enumerator(atPath: root.path) else { continue }

            for case let name as String in walk where name.hasSuffix(".swift") {
                let text = try String(
                    contentsOf: root.appendingPathComponent(name), encoding: .utf8)
                found.append((
                    path: "\(target)/\(name.replacingOccurrences(of: "\\", with: "/"))",
                    text: text))
            }
        }

        return found.sorted { $0.path < $1.path }
    }

    /// Every C# source of the RENDERER, for a guard that has to hold across the
    /// boundary. A name is only one name if both halves spell it the same, and
    /// nothing but a test can say so: the two sides never compile together.
    static func runtimeSources() throws -> [(path: String, text: String)] {
        let root = repository.appendingPathComponent("src/StateUI.Runtime")
        var found: [(path: String, text: String)] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else { return [] }

        for case let name as String in walk where name.hasSuffix(".cs") {
            // obj/ holds generated copies - AssemblyInfo and the like - and on
            // a machine that has built for four platforms it also holds four
            // stale copies of everything. Reading them would be reading the
            // PREVIOUS round's names.
            let path = name.replacingOccurrences(of: "\\", with: "/")
            if path.hasPrefix("obj/") || path.hasPrefix("bin/") { continue }

            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            found.append((path: path, text: text))
        }

        return found.sorted { $0.path < $1.path }
    }

    /// Every C# test source, for a guard asking whether the OTHER side proves
    /// something. The renderer's half of an event is tested there.
    static func runtimeTestSources() throws -> [(path: String, text: String)] {
        let root = repository.appendingPathComponent("src/Tests/StateUIRuntime.Tests")
        var found: [(path: String, text: String)] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else { return [] }

        for case let name as String in walk where name.hasSuffix(".cs") {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            found.append((path: name.replacingOccurrences(of: "\\", with: "/"), text: text))
        }

        return found.sorted { $0.path < $1.path }
    }

    /// Every fixture SIDECAR - the readable half of the cross-language
    /// contract. A name that appears in one is a name the C# side applies.
    static func fixtureSidecars() throws -> [String] {
        let root = repository.appendingPathComponent("src/Tests/fixtures")
        var found: [String] = []

        guard let walk = FileManager.default.enumerator(atPath: root.path) else { return [] }

        for case let name as String in walk where name.hasSuffix(".txt") {
            found.append(try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8))
        }

        return found
    }

    /// Node types described under Views/ that are not VIEWS.
    ///
    /// MAUI's SwipeItem is a MenuItem - a caption, a picture and something to
    /// run - and SwipeItems is the collection holding them. Neither can be
    /// built on its own, placed anywhere else, or styled, so neither has a
    /// fixture of its own nor a StyleTarget conformance. They are described in
    /// SwipeView.swift because that is the only place they appear, and their
    /// modifiers are exercised by the SwipeView case, which builds both.
    ///
    /// A ToolbarItem and the menu types are MenuItems in MAUI - a caption, a
    /// picture and something to run - and they belong to a PAGE rather than
    /// sitting in one, so they have no fixture and no style. Their modifiers are
    /// exercised by `PageBarTests`, which is where a page is described.
    ///
    /// A Span is one run of text inside a Label and MAUI's own class for it is a
    /// BindableObject, not a VisualElement - no opacity, no margin, no size - so
    /// it can neither be built alone nor styled. FormattedString is the
    /// collection holding the runs, exactly as SwipeItems holds swipe items.
    /// Both are exercised by the Label case, which builds them.
    ///
    /// The alternative would be leaving SwipeView.swift out of the scan
    /// altogether, the way the page arrangements are - which would take the
    /// SwipeView with them.
    /// ContextFlyout is the one written by a MODIFIER rather than by a type:
    /// `.contextFlyout` on any view appends it, MAUI's own ContextFlyout being
    /// an attached property. It is a MenuFlyout on that side - an Element, not a
    /// view - and the entries in it are the menu bar's, already here. Covered by
    /// ContextMenuTests on both sides rather than by a control fixture, for the
    /// reason the toolbar's are: there is no control to build one on.
    /// A Pin is a map's marker - a label, an address and a point, MAUI's Pin
    /// being a plain BindableObject - so it cannot be built alone or styled,
    /// and its modifiers are exercised by the Map case, which builds both.
    /// EmptyView is the furniture slot a CarouselView carries - a wrapper node
    /// read by TYPE, holding one ordinary view. Exercised by the CarouselView
    /// case, which writes it.
    static let notViews: Set<String> = [
        "SwipeItem", "SwipeItems",
        "FormattedString", "Span",
        "EmptyView",
        "ToolbarItem", "MenuBarItem",
        "MenuFlyoutItem", "MenuFlyoutSubItem", "MenuFlyoutSeparator",
        "ContextFlyout",
        "Pin",
    ]

    /// The files under Views/ that describe controls.
    ///
    /// Application.swift and Style.swift describe the application and the
    /// styles its controls are given - neither a control, and each with tests
    /// of its own; Elements.swift and ViewBuilder.swift describe no type at
    /// all.
    ///
    /// NavigationPage.swift and TabbedPage.swift are the same kind of thing: a
    /// PAGE arranges other pages, so there is no control to build one on and
    /// nothing about it can be styled - what they do is a stack and a set of
    /// tabs, and NavigationPageTests and TabbedPageTests are where those are
    /// checked, on both sides. ModalStack.swift arranges pages too, over the
    /// window rather than inside it.
    static func controlSources() throws -> [String] {
        let views = sources.appendingPathComponent("Views")
        let skipped: Set = [
            "Application.swift", "Style.swift", "ViewBuilder.swift",
            "NavigationPage.swift", "TabbedPage.swift", "FlyoutPage.swift",
            "ModalStack.swift",
        ]

        return try FileManager.default
            .contentsOfDirectory(atPath: views.path)
            .filter { $0.hasSuffix(".swift") && !skipped.contains($0) }
            .sorted()
    }
}

extension String {
    /// Every piece of text between an opening marker and the next closing one.
    /// An empty opening marker means "from here". The ONE copy of this helper,
    /// internal so BridgeTests and the token guard read with the same eyes.
    /// The same, but only where `opening` starts a WORD.
    ///
    /// `set(.` is the private setter a type that cannot write `setValue` keeps
    /// - and it is also the tail of `offset(.` and `inset(.`, which set
    /// nothing. Requiring the character before it to be one an identifier
    /// cannot contain is what tells the two apart.
    func words(before opening: String, upTo closing: String) -> [String] {
        var found: [String] = []
        var rest = Substring(self)

        while let start = rest.range(of: opening) {
            let previous = rest[..<start.lowerBound].last
            rest = rest[start.upperBound...]

            guard let end = rest.range(of: closing) else { break }

            if previous == nil || !(previous!.isLetter || previous!.isNumber || previous! == "_") {
                found.append(String(rest[..<end.lowerBound]))
            }

            rest = rest[end.upperBound...]
        }

        return found
    }

    func occurrences(between opening: String, and closing: String) -> [String] {
        var found: [String] = []
        var rest = Substring(self)

        while true {
            if opening.isEmpty {
                guard let end = rest.range(of: closing) else { break }
                found.append(String(rest[..<end.lowerBound]))
                return found
            }

            guard let start = rest.range(of: opening) else { break }
            rest = rest[start.upperBound...]

            guard let end = rest.range(of: closing) else { break }
            found.append(String(rest[..<end.lowerBound]))
            rest = rest[end.upperBound...]
        }

        return found
    }
}

extension Patch {
    /// The child patch for an identity, or nil when the message says nothing
    /// about it - which is the usual answer and the one worth asserting.
    func child(_ id: ElementId) -> Patch? {
        children.first { $0.id == id }
    }

    func child(_ id: String) -> Patch? { child(.manual(id)) }

    var propNames: [Prop] { props.keys.sorted() }
}

extension ElementId: CustomStringConvertible {
    public var description: String {
        switch self {
        case .auto(let value): return "\(value)"
        case .manual(let value): return "\"\(value)\""
        }
    }
}

/// A label, as short as the tests need one.
func label(_ text: String, id: String? = nil) -> Node {
    Node(type: "Label", id: id, props: ["text": .string(text)])
}

/// A button with a click handler, for the tests about handler ids.
func button(_ text: String, id: String? = nil, onClicked: @escaping EventHandler) -> Node {
    var node = Node(type: "Button", id: id, props: ["text": .string(text)])
    node.events["clicked"] = onClicked
    return node
}

func stack(_ children: [Node], id: String? = nil) -> Node {
    Node(type: "VerticalStackLayout", id: id, children: children)
}

/// Runs the closure with the system theme set to `theme`, and puts back
/// whatever it was.
///
/// The theme is what `Color(light:dark:)` reads as it is written onto a node -
/// see Types/Color.swift - so this is how a test asks for the other half. The
/// provider is the one the host pushes into, which is exactly what a real
/// theme change writes.
func withTheme(_ theme: AppTheme, _ body: () -> Void) {
    let held = StandardEnvironment.app.requestedTheme
    StandardEnvironment.app.requestedTheme = theme
    defer { StandardEnvironment.app.requestedTheme = held }

    body()
}
