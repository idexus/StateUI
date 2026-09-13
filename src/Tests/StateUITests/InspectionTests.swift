// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT AN INSPECTOR IS SHOWN, written down by the walk itself: every composed
// view a render reached - built, with the reason it could not be carried;
// carried; or walked past on the way to one below it that was built - and the
// host's half beside it, landing on the pass it names. And where an inspector
// shows: every scene has its own.

import StateUIWireProbe
import XCTest
@_spi(Host) @testable import StateUI

/// A state an author keeps on a model.
private final class Counts {
    @State var count = 0
}

/// A composed view built with one value.
private struct Titled: ContentView {
    let text: String

    var content: any View { Label(text) }
}

/// A composed view that reads the model's count.
private struct Reads: ContentView {
    let counts: Counts

    var content: any View { Label("\(counts.count)") }
}

/// A composed view holding both.
private struct Holds: ContentView {
    let counts: Counts

    var content: any View {
        VStack {
            Titled(text: "fixed")
            Reads(counts: counts)
        }
    }
}

/// A page with nothing on it.
private struct Blank: ContentPage {
    var content: any View { Label("blank") }
}

/// A scene's main window.
private struct First: Window {
    var page: any Page { Blank() }
}

/// What an inspector holds, for the test that writes it - a model at file
/// scope, the one place a `let` of one stays the same instance.
private final class Drawn: @unchecked Sendable {
    @State var revision = 0
}

private let drawn = Drawn()

/// A page that reads it, so a write to it has a reader.
private struct Showing: ContentPage {
    var content: any View { Label("\(drawn.revision)") }
}

private struct ShowingWindow: Window {
    var page: any Page { Showing() }
}

private struct ShowingApplication: Application {
    var scene: any Scene { ShowingWindow() }
}

/// An application holding state of its own, the way an application holds
/// what every session shares.
private struct Holding: Application {
    @State var menuOpen = false

    var scene: any Scene { First() }
}

/// An application whose scenes are a window alone.
private struct Plain: Application {
    var scene: any Scene { First() }
}

/// A scene whose inspector may show in a window of its own.
private struct Inspected: Scene {
    var windows: Windows {
        Windows {
            WindowGroup(.debugInspector) { DebugInspector() }
        } main: {
            First()
        }
    }
}

private struct InspectedApp: Application {
    var scene: any Scene { Inspected() }
}

final class InspectionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Scenes.shared.reset()
        Inspection.start()
    }

    override func tearDown() {
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
        Scenes.shared.reset()
        super.tearDown()
    }

    /// One render, opened and closed the way `Renderer.renderWire` does it.
    private func pass(
        _ road: InspectedPass.Road = .build,
        generation: Int32 = 1,
        _ render: () -> Void
    ) -> InspectedPass? {
        Inspection.begin(road: road, causes: [])
        render()
        Inspection.end(generation: generation, describe: 0, encode: 0, bytes: 0, keep: true)

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

    /// Two scenes, the way the platform hands them over.
    private func twoScenes() {
        Scenes.shared.connected(restoring: [:])
        Scenes.shared.connected(restoring: [:])
    }

    /// What each scene's main window holds, by type.
    private func slots() -> [[NodeType]] {
        Renders().render(Scenes.shared.tree(of: Plain())).children.map {
            $0.children[0].children.map(\.type)
        }
    }

    /// What the inspector docked over each scene's main window says - its
    /// labels and its buttons, in walk order; nothing where none docks.
    private func docked() -> [[String]] {
        Renders().render(Scenes.shared.tree(of: Plain())).children.map { scene in
            scene.children[0].children.filter { $0.type == .overlay }.flatMap { words(in: $0) }
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
        let text = patch.type == .label || patch.type == .button ? patch.props[.text]?.string : nil
        let own = [text, patch.props[.semanticDescription]?.string].compactMap { $0 }

        return own + patch.children.flatMap { words(in: $0) }
    }

    // MARK: - As text

    /// A pass is written out as text once the host has said what applying it
    /// cost - what the host prints for `STATEUI_INSPECT=1` - and taken once.
    func testAPassIsWrittenOutOnceTheHostReportsOnIt() throws {
        Inspection.logging = true

        let first = try XCTUnwrap(pass(generation: 7) { Renders().render(Holds(counts: Counts()).body) })

        XCTAssertEqual(Inspection.takeLog(), "", "written before the host reported on it")

        Inspection.applied(
            generation: 7,
            InspectedHost(read: 12, apply: 340, nodes: 5, made: 2, kept: 3, adopted: 0))

        let lines = Inspection.takeLog().split(separator: "\n").map(String.init)
        let head = try XCTUnwrap(lines.first)

        XCTAssertTrue(head.hasPrefix("StateUI inspect #\(first.number) build at "), head)
        XCTAssertTrue(head.contains(" · C# 352 µs, 5 nodes, 2 made, 3 kept, 0 adopted · 3 built · 0 carried"), head)
        XCTAssertEqual(lines.dropFirst().map { $0.components(separatedBy: " · ")[0] }, [
            "  ● Holds — first time",
            "    ● Titled — first time",
            "    ● Reads — first time",
        ])
        XCTAssertEqual(Inspection.takeLog(), "", "a pass taken is written once")
    }

    // MARK: - The tree

    func testAFirstRenderBuildsEveryComposedViewForTheFirstTime() {
        let first = pass { Renders().render(Holds(counts: Counts()).body) }

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
            }.body
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

        renders.render(Holds(counts: counts).body)
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

        let first = pass { Renders().render(Scenes.shared.tree(of: Plain())) }
        let scenes = Set((first?.entries ?? []).filter { $0.depth == 0 }.map(\.scene))

        XCTAssertEqual(scenes, [.manual("1"), .manual("2")])
    }

    /// An element's time holds the entries under it, and its own leaves them
    /// out.
    func testAnEntrysOwnTimeLeavesOutWhatIsUnderIt() throws {
        let first = try XCTUnwrap(pass { Renders().render(Holds(counts: Counts()).body) })
        let outer = first.entries[0]
        let under = first.entries[1].micros + first.entries[2].micros

        XCTAssertGreaterThanOrEqual(outer.micros, under)
        XCTAssertEqual(outer.own, outer.micros - under, accuracy: 0.001)
    }

    func testNothingIsWrittenWhileNobodyRecords() {
        Inspection.stop()

        Renders().render(Holds(counts: Counts()).body)

        XCTAssertFalse(Inspection.enter("Anything", .carried))
        XCTAssertTrue(Inspection.passes.isEmpty)
    }

    /// The inspector's own views write no entries, and their time is kept
    /// apart - or every pass would record the inspector drawing the last one.
    func testTheInspectorsOwnViewsAreMutedAndTimedApart() {
        Inspection.ownViews = [String(reflecting: Titled.self)]

        let first = pass { Renders().render(Holds(counts: Counts()).body) }

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
        // DECODED, never thrown away: the probe's names are announced once,
        // and a later test decoding a message would meet one it never saw.
        Renderer.shared.setApplication(ShowingApplication())
        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))

        Inspection.ownStates = [ObjectIdentifier(try XCTUnwrap(drawn.$revision.described))]
        Inspection.clear()
        drawn.revision += 1

        // A baseline of nought is a host that holds nothing, which is what the
        // render after a failed apply is.
        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))

        XCTAssertTrue(Inspection.passes.isEmpty)
    }

    func testAPassTheInspectorCausedIsNotKept() {
        Inspection.begin(road: .walk, causes: ["revision"])
        Inspection.end(generation: 2, describe: 0, encode: 0, bytes: 0, keep: false)

        XCTAssertTrue(Inspection.passes.isEmpty)
    }

    // MARK: - The host's half

    func testTheHostsHalfLandsOnThePassItNames() {
        _ = pass(generation: 6) { Renders().render(Label("six").body) }
        _ = pass(generation: 7) { Renders().render(Label("seven").body) }

        Inspection.applied(generation: 6, scene: 1, micros: 30)
        Inspection.applied(
            generation: 6,
            InspectedHost(read: 5, apply: 40, nodes: 3, made: 1, kept: 2, adopted: 0))

        XCTAssertEqual(Inspection.passes.first?.host?.apply, 40)
        XCTAssertEqual(Inspection.passes.first?.host?.scenes, [0, 30])
        XCTAssertNil(Inspection.passes.last?.host)
    }

    // MARK: - Where it shows

    /// Every scene has its own inspector, and one docked is an overlay on that
    /// scene's main window alone.
    func testAnInspectorDocksInItsOwnScenesMainWindowAndNoOther() {
        twoScenes()

        Inspector.show(in: Scenes.shared.list[1], .side)
        XCTAssertEqual(slots(), [[.contentPage], [.contentPage, .overlay]])

        Inspector.show(in: Scenes.shared.list[0], .bottom)
        XCTAssertEqual(slots(), [[.contentPage, .overlay], [.contentPage, .overlay]])

        Inspector.hide(in: Scenes.shared.list[1])
        XCTAssertEqual(slots(), [[.contentPage, .overlay], [.contentPage]])
    }

    /// In a window of its own, an inspector is a window OF ITS SCENE - the
    /// scene's `DebugInspector`, beside its main window.
    func testAnInspectorInAWindowIsAWindowOfItsScene() {
        let renders = Renders()

        // Built once, so the scene has said which groups it declares.
        renders.render(Scenes.shared.tree(of: InspectedApp()))

        Inspector.show(in: Scenes.shared.list[0], .window)

        let whole = renders.renderFromScratch(Scenes.shared.tree(of: InspectedApp()))

        XCTAssertEqual(
            whole.children[0].children.map(\.id),
            [.manual("main"), .manual("stateui.debugInspector 1")])
        XCTAssertNil(InspectorModel.shared.places["1"])
    }

    /// A scene that declares no window for it has its inspector DOCK instead -
    /// the window is a place a scene offers, never one the library makes.
    func testAnInspectorWithNoWindowToShowInDocks() {
        Renders().render(Scenes.shared.tree(of: Plain()))

        Inspector.show(in: Scenes.shared.list[0], .window)

        XCTAssertEqual(InspectorModel.shared.places["1"], .bottom)
        XCTAssertTrue(Scenes.shared.list[0].windows.isEmpty)
    }

    /// The ⓘ opens the inspector of the scene whose session it is handed, and
    /// closes it again - which is what makes each scene's its own.
    func testAButtonOpensTheInspectorOfItsOwnScene() {
        twoScenes()

        let second = Scenes.shared.list[1].session

        Inspector.toggle(in: second)
        XCTAssertEqual(Array(InspectorModel.shared.places.keys), ["2"])
        XCTAssertTrue(Inspector.isOpen(in: second))
        XCTAssertFalse(Inspector.isOpen(in: Scenes.shared.list[0].session))

        Inspector.toggle(in: second)
        XCTAssertTrue(InspectorModel.shared.places.isEmpty)
    }

    /// A scene that ends takes its docked inspector with it - and the record
    /// stops once no inspector shows, which is what an application that ships
    /// the button relies on.
    func testAnInspectorEndsWithItsScene() {
        twoScenes()

        Inspector.show(in: Scenes.shared.list[1], .bottom)
        Scenes.shared.ended(Scenes.shared.list[1])

        XCTAssertTrue(InspectorModel.shared.places.isEmpty)
        XCTAssertFalse(Inspection.recording)
    }

    /// Docked along the bottom, an inspector folds to one line - the last
    /// render that reached its scene - and opens out again; the scene beside
    /// it keeps its own, and an inspector shown at a place is shown whole.
    func testAnInspectorAlongTheBottomFoldsToItsLastRender() {
        twoScenes()

        _ = pass { Renders().render(Scenes.shared.tree(of: Plain())) }

        Inspector.show(in: Scenes.shared.list[0], .bottom)
        Inspector.show(in: Scenes.shared.list[1], .bottom)
        InspectorModel.shared.collapsed.insert("1")

        let folded = docked()

        XCTAssertEqual(folded[0].first, "#1  build  ")
        XCTAssertEqual(Array(folded[0].suffix(2)), ["Expand", "Close"])
        XCTAssertFalse(folded[0].contains("Collapse"))
        XCTAssertEqual(pair(from: "Collapse", in: folded[1]), ["Collapse", "Close"])

        InspectorModel.shared.expand("1")
        XCTAssertTrue(docked()[0].contains("Collapse"))

        InspectorModel.shared.collapsed.insert("1")
        Inspector.show(in: Scenes.shared.list[0], .side)
        Inspector.show(in: Scenes.shared.list[0], .bottom)
        XCTAssertTrue(docked()[0].contains("Collapse"))
    }

    /// The ⓘ opens an inspector along the bottom FOLDED to its last render,
    /// its line ending in the two buttons that open it out and close it - and
    /// asked for a place, an inspector is shown whole there, ending in the two
    /// that fold it and close it.
    func testTheButtonOpensTheInspectorFoldedAlongTheBottom() {
        twoScenes()

        _ = pass { Renders().render(Scenes.shared.tree(of: Plain())) }

        let first = Scenes.shared.list[0].session

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
        func pass(_ number: Int, in scene: ElementId) -> InspectedPass {
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
