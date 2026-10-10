// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT AN INSPECTOR IS SHOWN, written down by the walk itself: every composed
// view a render reached - built, with the reason it could not be carried;
// carried; or walked past on the way to one below it that was built - and the
// host's half beside it, landing on the pass it names. And where an inspector
// shows: every scene has its own.

import XCTest
@_spi(Host) @testable import StateUI

/// A state an author keeps on a model.
@MainActor
private final class Counts {
    @State var count = 0
}

/// A composed view built with one value.
private struct Titled: View {
    let text: String

    var body: some View { Text(text) }
}

/// A composed view that reads the model's count.
private struct Reads: View {
    let counts: Counts

    var body: some View { Text("\(counts.count)") }
}

/// A composed view holding both.
private struct Holds: View {
    let counts: Counts

    var body: some View {
        VStack {
            Titled(text: "fixed")
            Reads(counts: counts)
        }
    }
}

/// A page with nothing on it.
private struct Blank: View {
    var body: some View { Text("blank") }
}

/// A scene's main window.
private struct First: View {
    var body: some View { Blank() }
}

/// What an inspector holds, for the test that writes it - a model at file
/// scope, the one place a `let` of one stays the same instance.
@MainActor
private final class Drawn: @unchecked Sendable {
    @State var revision = 0
}

@MainActor
private let drawn = Drawn()

/// A page that reads it, so a write to it has a reader.
private struct Showing: View {
    var body: some View { Text("\(drawn.revision)") }
}

private struct ShowingApplication: Application {
    var body: some Scene { WindowGroup { Showing() } }
}

/// An application holding state of its own, the way an application holds
/// what every session shares.
private struct Holding: Application {
    @State var menuOpen = false

    var body: some Scene { WindowGroup { First() } }
}

private extension WindowType {
    static let second = WindowType("inspection.second")
}

/// An application of two scenes, each a window alone.
private struct Plain: Application {
    var body: some Scene {
        WindowGroup { First() }
        Window(.second) { First() }
    }
}

/// A scene whose inspector may show in a window of its own.
private struct Inspected: Scene {
    var body: some Scene {
        WindowGroup { First() }
        Window(.debugInspector) { DebugInspector() }
    }
}

private struct InspectedApp: Application {
    var body: some Scene { Inspected() }
}

@MainActor
final class InspectionTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.setApplication(Plain())
        Inspection.start()
    }

    override func tearDown() async throws {
        InspectorModel.shared.places = [:]
        InspectorModel.shared.collapsed = []
        InspectorModel.shared.selected = nil
        InspectorModel.shared.windows = 0
        Inspection.logging = false
        Inspection.stop()
        Inspection.ownViews = []
        Inspection.ownStates = []

        // NOT LEFT INSTALLED: a pass the next test keeps would otherwise start
        // the inspector's paced rebuild, a sleeping task another test counts.
        Inspection.landed = nil
        OpenScenes.shared.reset()
    }

    /// One render, opened and closed the way `Renderer.renderHost` does it.
    private func pass(
        _ road: InspectedPass.Road = .build,
        generation: Int32 = 1,
        _ render: () -> Void
    ) -> InspectedPass? {
        Inspection.begin(road: road, causes: [])
        render()
        Inspection.end(generation: generation, describe: 0, keep: true)

        return Inspection.passes.last
    }

    /// A pass's tree as lines, indented by depth.
    private func said(_ pass: InspectedPass?) -> [String] {
        (pass?.entries ?? []).map { entry in
            let outcome: String

            switch entry.outcome {
            case let .built(reason): outcome = reason
            case .carried: outcome = "carried"
            case .walked: outcome = "walked"
            }

            return String(repeating: "  ", count: entry.depth) + "\(entry.view): \(outcome)"
        }
    }

    /// The registered application's tree, the way `Renderer.root` builds it.
    private func tree() -> Node {
        OpenScenes.shared.tree(of: Renderer.shared.madeApplication()!)
    }

    /// Two scenes, the way the platform hands their windows over.
    private func twoScenes() {
        HostBoundary.connectWindow()
        HostBoundary.connectWindow(kind: WindowType.second.name)
    }

    /// What each window of each scene holds, by type.
    private func slots() -> [[[NodeType]]] {
        Renders().render(tree()).children.map { scene in
            scene.children.map { $0.children.map(\.type) }
        }
    }

    /// What the inspector docked over each scene's first window says - its
    /// labels and its buttons, in walk order; nothing where none docks.
    private func docked() -> [[String]] {
        Renders().render(tree()).children.map { scene in
            scene.children[0].children.filter { $0.type == .overlay }.flatMap { words(in: $0) }
        }
    }

    /// Whether each window of the first scene holds the docked inspector.
    private func windowsHoldingTheInspector() -> [Bool] {
        let scene = Renders().render(tree()).children[0]
        return scene.children.map { window in
            window.children.contains { $0.type == .overlay && !words(in: $0).isEmpty }
        }
    }

    /// The word `first` and the one after it - how the two drawn buttons at
    /// the end of a panel's head are read, the list's rows coming after them.
    private func pair(from first: String, in words: [String]) -> [String] {
        guard let at = words.firstIndex(of: first), at + 1 < words.count else { return [] }

        return Array(words[at...(at + 1)])
    }

    /// Every label's and button's text under a patch, and the word a drawn
    /// button says for itself, in walk order.
    private func words(in patch: HostPatch) -> [String] {
        let text = patch.type == .text || patch.type == .button ? patch.props[.text]?.string : nil
        let own = [text, patch.props[.accessibilityLabel]?.string].compactMap { $0 }

        return own + patch.children.flatMap { words(in: $0) }
    }

    // MARK: - As text

    /// A pass is written out as text once the host has said what applying it
    /// cost - what the host prints for `STATEUI_INSPECT=1` - and taken once.
    func testAPassIsWrittenOutOnceTheHostReportsOnIt() throws {
        Inspection.logging = true

        let first = try XCTUnwrap(pass(generation: 7) { Renders().render(Holds(counts: Counts()).node) })

        XCTAssertEqual(Inspection.takeLog(), "", "written before the host reported on it")

        Inspection.applied(
            generation: 7,
            InspectedHost(apply: 352, nodes: 5, made: 2, kept: 3))

        let lines = Inspection.takeLog().split(separator: "\n").map(String.init)
        let head = try XCTUnwrap(lines.first)

        XCTAssertTrue(head.hasPrefix("StateUI inspect #\(first.number) build at "), head)
        XCTAssertTrue(head.contains(" · host 352 µs, 5 nodes, 2 made, 3 kept · 3 built · 0 carried"), head)
        XCTAssertEqual(lines.dropFirst().map { $0.components(separatedBy: " · ")[0] }, [
            "  ● Holds — first time",
            "    ● Titled — first time",
            "    ● Reads — first time",
        ])
        XCTAssertEqual(Inspection.takeLog(), "", "a pass taken is written once")
    }

    // MARK: - The tree

    /// A view is named by its type alone, and a placeholder the library puts around one - a page, a window - by
    /// its kind and the view's name, so no bracket is left hanging.
    func testAPlaceholderIsNamedByItsKindAndItsView() {
        XCTAssertEqual(Inspection.short("GalleryUI.MainPage"), "MainPage")
        XCTAssertEqual(Inspection.short("Swift.Array<Swift.Int>"), "Array")
        XCTAssertEqual(Inspection.short("StateUI.Window(GalleryUI.MainPage)"), "Window(MainPage)")
        XCTAssertEqual(Inspection.short("StateUI.Page(GalleryUI.HomePage#home@if)"), "Page(HomePage#home@if)")
    }

    func testAFirstRenderBuildsEveryComposedViewForTheFirstTime() {
        let first = pass { Renders().render(Holds(counts: Counts()).node) }

        XCTAssertEqual(said(first), [
            "Holds: first time",
            "  Titled: first time",
            "  Reads: first time",
        ])
    }

    /// The reason is the first of the carry's questions to say no - here the
    /// input that changed, by the property that holds it.
    func testARenderSaysWhyItBuiltAViewItCouldNotCarry() {
        let renders = Renders()
        let counts = Counts()

        func tree(_ text: String) -> Node {
            VStack {
                Titled(text: text)
                Reads(counts: counts)
            }.node
        }

        renders.render(tree("a"))

        let second = pass { renders.render(tree("b")) }

        XCTAssertEqual(said(second), [
            "Titled: built with a new text",
            "Reads: carried",
        ])
    }

    /// A clean walk writes down only the path to what it built: the view it
    /// walked through, and the reader below it named by the state it read.
    func testACleanWalkWritesThePathToWhatItBuilt() {
        let renders = Renders()
        let counts = Counts()

        renders.render(Holds(counts: counts).node)
        counts.count += 1

        let walked = pass(.walk) { renders.revisit(changed: Renderer.shared.pendingChanges) }

        XCTAssertEqual(said(walked), [
            "Holds: walked",
            "  Reads: for count",
        ])

        // Both filed under the element at depth 0, which in an application is
        // its scene.
        let scenes = Set((walked?.entries ?? []).map(\.scene))
        XCTAssertEqual(scenes.count, 1)
        XCTAssertNotNil(scenes.first ?? nil)
    }

    /// A render is filed under the SCENE it reached - its entry at depth 0 is
    /// the scene's own.
    func testARenderIsFiledUnderTheScenesItReached() {
        twoScenes()

        let first = pass { Renders().render(tree()) }
        let scenes = Set((first?.entries ?? []).filter { $0.depth == 0 }.map(\.scene))

        XCTAssertEqual(scenes, [.manual("1"), .manual("2")])
    }

    /// An element's time holds the entries under it, and its own leaves them
    /// out.
    func testAnEntrysOwnTimeLeavesOutWhatIsUnderIt() throws {
        let first = try XCTUnwrap(pass { Renders().render(Holds(counts: Counts()).node) })
        let outer = first.entries[0]
        let under = first.entries[1].micros + first.entries[2].micros

        XCTAssertGreaterThanOrEqual(outer.micros, under)
        XCTAssertEqual(outer.own, outer.micros - under, accuracy: 0.001)
    }

    func testNothingIsWrittenWhileNobodyRecords() {
        Inspection.stop()

        Renders().render(Holds(counts: Counts()).node)

        XCTAssertFalse(Inspection.enter("Anything", .carried))
        XCTAssertTrue(Inspection.passes.isEmpty)
    }

    /// The inspector's own views write no entries, and their time is kept
    /// apart - or every pass would record the inspector drawing the last one.
    func testTheInspectorsOwnViewsAreMutedAndTimedApart() {
        Inspection.ownViews = [String(reflecting: Titled.self)]

        let first = pass { Renders().render(Holds(counts: Counts()).node) }

        XCTAssertEqual(said(first), [
            "Holds: first time",
            "  Reads: first time",
        ])
        XCTAssertGreaterThan(first?.own ?? 0, 0)
    }

    /// A render the inspector's own state alone caused is not kept WHICHEVER
    /// ROAD IT TOOK. After a failed apply the host asks for everything, and a
    /// complete render kept here asked the inspector to draw again, for good -
    /// measured as a gallery going round at half a core behind its error page.
    func testACompleteRenderTheInspectorAloneCausedIsNotKept() throws {
        Renderer.shared.setApplication(ShowingApplication())
        _ = Renderer.shared.renderHost(baseline: 0)

        Inspection.ownStates = [ObjectIdentifier(try XCTUnwrap(drawn.$revision.described))]
        Inspection.clear()
        drawn.revision += 1

        // A baseline of nought is a host that holds nothing, which is what the
        // render after a failed apply is.
        _ = Renderer.shared.renderHost(baseline: 0)

        XCTAssertTrue(Inspection.passes.isEmpty)
    }

    func testAPassTheInspectorCausedIsNotKept() {
        Inspection.begin(road: .walk, causes: ["revision"])
        Inspection.end(generation: 2, describe: 0, keep: false)

        XCTAssertTrue(Inspection.passes.isEmpty)
    }

    // MARK: - The host's half

    func testTheHostsHalfLandsOnThePassItNames() {
        _ = pass(generation: 6) { Renders().render(Text("six").node) }
        _ = pass(generation: 7) { Renders().render(Text("seven").node) }

        Inspection.applied(generation: 6, scene: 1, micros: 30)
        Inspection.applied(
            generation: 6,
            InspectedHost(apply: 40, nodes: 3, made: 1, kept: 2))

        XCTAssertEqual(Inspection.passes.first?.host?.apply, 40)
        XCTAssertEqual(Inspection.passes.first?.host?.scenes, [0, 30])
        XCTAssertNil(Inspection.passes.last?.host)
    }

    // MARK: - Where it shows

    /// Every scene has its own inspector, and one docked is an overlay on that
    /// scene's first window alone.
    func testAnInspectorDocksInItsOwnScenesFirstWindowAndNoOther() throws {
        twoScenes()
        try OpenScenes.shared.open(nil)

        Inspector.show(in: OpenScenes.shared.list[1], .side)
        XCTAssertEqual(slots(), [[[.page], [.page]], [[.page, .overlay]]])

        Inspector.show(in: OpenScenes.shared.list[0], .bottom)
        XCTAssertEqual(slots(), [[[.page, .overlay], [.page]], [[.page, .overlay]]])

        Inspector.hide(in: OpenScenes.shared.list[1])
        XCTAssertEqual(slots(), [[[.page, .overlay], [.page]], [[.page]]])
    }

    /// A docked inspector is a value of its scene, whose panel the library lays as its first window's own overlay,
    /// after its page - over every overlay a page declares - and hiding it takes the layer away.
    func testADockedInspectorIsTheFirstWindowsOwnOverlay() throws {
        HostBoundary.connectWindow()
        let record = try XCTUnwrap(OpenScenes.shared.list.first)

        Inspector.show(in: record, .bottom)
        XCTAssertEqual(record.dockedInspector?.place, .bottom)
        let built = try XCTUnwrap(Renders().render(tree()).children.first?.children.first)
        XCTAssertEqual(built.children.last?.type, .overlay)
        XCTAssertEqual(built.children.last?.children.first?.type, .zStack)

        Inspector.hide(in: record)
        XCTAssertNil(record.dockedInspector)
    }

    /// The first window closing hands the docked inspector to the window that is first then.
    func testADockedInspectorMovesToTheWindowFirstNow() throws {
        let renders = Renders()
        renders.render(tree())
        try OpenScenes.shared.open(nil)
        let record = try XCTUnwrap(OpenScenes.shared.list.first)
        Inspector.show(in: record, .bottom)
        let docked = renders.render(tree(), changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(docked.at(.manual("1"), .manual("window 2"))?.children.map(\.type), [.page])

        try record.closeWindow(key: "window 1")
        let moved = renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(moved.at(.manual("1"))?.arrangement, [.manual("window 2")])
        XCTAssertEqual(
            moved.at(.manual("1"), .manual("window 2"))?.children.map(\.type), [.page, .overlay],
            "the window first now docks it, in the render that closed the other")
    }

    /// In a window of its own, an inspector is a window OF ITS SCENE - the
    /// scene's `DebugInspector`, beside the window it was opened from.
    func testAnInspectorInAWindowIsAWindowOfItsScene() {
        Renderer.shared.setApplication(InspectedApp())
        let renders = Renders()
        renders.render(tree())

        Inspector.show(in: OpenScenes.shared.list[0], .window)

        let whole = renders.renderFromScratch(tree())

        XCTAssertEqual(
            whole.children[0].children.map(\.id),
            [.manual("window 1"), .manual("stateui.debugInspector 2")])
        XCTAssertNil(InspectorModel.shared.places["1"])
    }

    /// A scene that declares no window for it has its inspector DOCK instead -
    /// the window is a place a scene offers, never one the library makes.
    func testAnInspectorWithNoWindowToShowInDocks() {
        Renders().render(tree())

        Inspector.show(in: OpenScenes.shared.list[0], .window)

        XCTAssertEqual(InspectorModel.shared.places["1"], .bottom)
        XCTAssertEqual(OpenScenes.shared.list[0].windows.map(\.key), ["window 1"])
    }

    /// The ⓘ opens the inspector of the scene whose window it is handed, and
    /// closes it again - which is what makes each scene's its own.
    func testAButtonOpensTheInspectorOfItsOwnScene() {
        twoScenes()

        let second = OpenScenes.shared.list[1]
        let window = second.windowSession(second.windows[0].key)

        Inspector.toggle(in: window)
        XCTAssertEqual(Array(InspectorModel.shared.places.keys), ["2"])
        XCTAssertTrue(Inspector.isOpen(in: window))
        let other = OpenScenes.shared.list[0]
        XCTAssertFalse(Inspector.isOpen(in: other.windowSession(other.windows[0].key)))

        Inspector.toggle(in: window)
        XCTAssertTrue(InspectorModel.shared.places.isEmpty)
    }

    /// The ⓘ docks the inspector in the window it is pressed in; pressed in
    /// another window of the scene, it moves the inspector there, open; pressed
    /// again where the inspector stands, it closes it.
    func testTheButtonDocksTheInspectorInItsOwnWindow() {
        HostBoundary.connectWindow()
        HostBoundary.connectWindow()
        _ = pass { Renders().render(tree()) }
        let scene = OpenScenes.shared.list[0]
        XCTAssertEqual(scene.windows.count, 2)
        let (first, second) = (scene.windowSession(scene.windows[0].key), scene.windowSession(scene.windows[1].key))

        Inspector.toggle(in: second)
        XCTAssertEqual(windowsHoldingTheInspector(), [false, true], "in the window it was pressed in")

        Inspector.toggle(in: first)
        XCTAssertEqual(windowsHoldingTheInspector(), [true, false], "moved, and open")
        XCTAssertTrue(Inspector.isOpen(in: second), "open in every window's sense")

        Inspector.toggle(in: first)
        XCTAssertFalse(Inspector.isOpen(in: second), "pressed where it stands, it closes")
    }

    /// A scene that ends takes its docked inspector with it - and the record
    /// stops once no inspector shows, which is what an application that ships
    /// the button relies on.
    func testAnInspectorEndsWithItsScene() {
        twoScenes()

        Inspector.show(in: OpenScenes.shared.list[1], .bottom)
        OpenScenes.shared.ended(OpenScenes.shared.list[1])

        XCTAssertTrue(InspectorModel.shared.places.isEmpty)
        XCTAssertFalse(Inspection.recording)
    }

    /// Docked along the bottom, an inspector folds to one line - the last
    /// render that reached its scene - and opens out again; the scene beside
    /// it keeps its own, and an inspector shown at a place is shown whole.
    func testAnInspectorAlongTheBottomFoldsToItsLastRender() {
        twoScenes()

        _ = pass { Renders().render(tree()) }

        Inspector.show(in: OpenScenes.shared.list[0], .bottom)
        Inspector.show(in: OpenScenes.shared.list[1], .bottom)
        InspectorModel.shared.collapsed.insert("1")

        let folded = docked()

        XCTAssertEqual(folded[0].first, "#1  build  ")
        XCTAssertEqual(Array(folded[0].suffix(2)), ["Expand", "Close"])
        XCTAssertFalse(folded[0].contains("Collapse"))
        XCTAssertEqual(pair(from: "Collapse", in: folded[1]), ["Collapse", "Close"])

        InspectorModel.shared.expand("1")
        XCTAssertTrue(docked()[0].contains("Collapse"))

        InspectorModel.shared.collapsed.insert("1")
        Inspector.show(in: OpenScenes.shared.list[0], .side)
        Inspector.show(in: OpenScenes.shared.list[0], .bottom)
        XCTAssertTrue(docked()[0].contains("Collapse"))
    }

    /// The ⓘ opens an inspector along the bottom FOLDED to its last render,
    /// its line ending in the two buttons that open it out and close it - and
    /// asked for a place, an inspector is shown whole there, ending in the two
    /// that fold it and close it.
    func testTheButtonOpensTheInspectorFoldedAlongTheBottom() {
        twoScenes()

        _ = pass { Renders().render(tree()) }

        let first = OpenScenes.shared.list[0].windowSession(OpenScenes.shared.list[0].windows[0].key)

        Inspector.toggle(in: first)

        XCTAssertEqual(InspectorModel.shared.places["1"], .bottom)
        XCTAssertEqual(InspectorModel.shared.collapsed, ["1"])
        XCTAssertEqual(Array(docked()[0].suffix(2)), ["Expand", "Close"])

        Inspector.open(.bottom, in: first)

        XCTAssertTrue(InspectorModel.shared.collapsed.isEmpty)
        XCTAssertEqual(pair(from: "Collapse", in: docked()[0]), ["Collapse", "Close"])
    }

    /// A scene's history is the renders that reached it.
    func testASceneHistoryIsTheRendersThatReachedIt() {
        func pass(_ number: Int, in scene: ElementID) -> InspectedPass {
            var pass = InspectedPass(at: 0, road: .walk, causes: [])
            pass.number = number
            pass.entries = [InspectedEntry(depth: 0, view: "Scene", scene: scene, outcome: .walked)]
            return pass
        }

        let passes = [pass(3, in: .manual("1")), pass(2, in: .manual("2")), pass(1, in: .manual("1"))]

        XCTAssertEqual(InspectorView.history(of: .manual("1"), in: passes).map(\.number), [3, 1])
    }

    // MARK: - Names

    /// A state the APPLICATION holds is named by its property too - found on
    /// screen as every flyout render reading `for Storage`, the menu's state
    /// living on the application, which nothing walks.
    func testAnApplicationsOwnStateIsNamedByItsProperty() {
        let application = Holding()

        Renderer.name(statesOf: application)

        XCTAssertEqual(application.$menuOpen.described?.origin, "menuOpen")
    }

    func testADifferenceIsNamedByItsProperty() {
        XCTAssertNil(Input.difference(
            [(path: "text", input: .value("a"))],
            [(path: "text", input: .value("a"))]))

        XCTAssertEqual(
            Input.difference(
                [(path: "text", input: .value("a"))],
                [(path: "text", input: .value("b"))]),
            "text")

        XCTAssertEqual(
            Input.difference(
                [(path: "_run", input: .opaque)],
                [(path: "_run", input: .opaque)]),
            "run, which cannot be compared")
    }
}
