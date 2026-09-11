// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT AN INSPECTOR IS SHOWN, written down by the walk itself: every composed
// view a render reached - built, with the reason it could not be carried;
// carried; or walked past on the way to one below it that was built - and the
// host's half beside it, landing on the pass it names.

import XCTest
@testable import StateUI

/// A state an author keeps on a model.
private final class Counts {
    @State var count = 0
}

/// A composed view built with one value.
private struct Titled: ContentView {
    let text: String

    var content: Element { Label(text) }
}

/// A composed view that reads the model's count.
private struct Reads: ContentView {
    let counts: Counts

    var content: Element { Label("\(counts.count)") }
}

/// A composed view holding both.
private struct Holds: ContentView {
    let counts: Counts

    var content: Element {
        VStack {
            Titled(text: "fixed")
            Reads(counts: counts)
        }
    }
}

/// A page with nothing on it.
private struct Blank: ContentPage {
    var content: Element { Label("blank") }
}

/// Two windows of an application.
private struct First: Window {
    var content: Page { Blank() }
}

private struct Second: Window {
    var content: Page { Blank() }
}

/// An application holding state of its own, the way the gallery holds its
/// navigation.
private struct Holding: Application {
    @State var menuOpen = false

    func createWindow() -> Window { First() }
}

final class InspectionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Inspection.start()
    }

    override func tearDown() {
        InspectorModel.shared.close()
        Inspection.stop()
        Inspection.ownViews = []
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
        XCTAssertEqual(walked?.entries.map(\.window), ["Holds", "Holds"])
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

    func testAPassTheInspectorCausedIsNotKept() {
        Inspection.begin(road: .walk, causes: ["revision"])
        Inspection.end(generation: 2, describe: 0, encode: 0, bytes: 0, keep: false)

        XCTAssertTrue(Inspection.passes.isEmpty)
    }

    // MARK: - The host's half

    func testTheHostsHalfLandsOnThePassItNames() {
        _ = pass(generation: 6) { Renders().render(Label("six").body) }
        _ = pass(generation: 7) { Renders().render(Label("seven").body) }

        Inspection.applied(generation: 6, window: 1, micros: 30)
        Inspection.applied(
            generation: 6,
            InspectedHost(read: 5, apply: 40, nodes: 3, made: 1, kept: 2, adopted: 0))

        XCTAssertEqual(Inspection.passes.first?.host?.apply, 40)
        XCTAssertEqual(Inspection.passes.first?.host?.windows, [0, 30])
        XCTAssertNil(Inspection.passes.last?.host)
    }

    // MARK: - Where it shows

    /// The panel is an overlay on the window being looked at, and only there;
    /// a window of its own is a window after the application's.
    func testThePanelGoesOverTheWindowBeingLookedAtAndNowhereElse() {
        func application() -> Node {
            Node(
                type: .application,
                children: [First().body(inspectedAt: 0), Second().body(inspectedAt: 1)]
                    + Inspector.windows)
        }

        func slots(_ patch: Patch) -> [[NodeType]] {
            patch.children.map { $0.children.map(\.type) }
        }

        InspectorModel.shared.open(.panel)

        XCTAssertEqual(
            slots(Differ().reconcile(nil, with: application()).patch),
            [[.contentPage, .overlay], [.contentPage]])

        InspectorModel.shared.looking = 1

        XCTAssertEqual(
            slots(Differ().reconcile(nil, with: application()).patch),
            [[.contentPage], [.contentPage, .overlay]])

        InspectorModel.shared.open(.window)

        XCTAssertEqual(
            slots(Differ().reconcile(nil, with: application()).patch),
            [[.contentPage], [.contentPage], [.contentPage]])
    }

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
