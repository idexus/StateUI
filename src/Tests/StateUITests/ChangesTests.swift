// `.onChanged` runs when the value is not what the element carried last render
// - and only then. See Core/Changes.swift for the four rules these tests pin.

import XCTest
@testable import StateUI

/// A view watching its own state, the way an application writes it.
private struct Watcher: ContentView {
    @State var count = 0
    let log: Log

    var content: Element {
        VStack {
            Button("Bump").onClicked { count += 1 }
        }
        .onChanged(count) { log.lines.append("moved") }
    }
}

/// The lines a handler wrote, shared with the test the way a `@State` box is:
/// a class, so the closure and the assert read one storage.
private final class Log: @unchecked Sendable {
    var lines: [String] = []
}

final class ChangesTests: XCTestCase {
    // MARK: - When it fires

    func testAChangedValueRunsTheHandler() {
        let renders = Renders()
        let log = Log()

        func tree(_ value: Int) -> Node {
            VStack { Label("\(value)") }
                .onChanged(value) { log.lines.append("fired") }
                .body
        }

        renders.render(tree(1))
        renders.render(tree(2))

        XCTAssertEqual(log.lines, ["fired"])
    }

    func testAnUnchangedValueDoesNotRun() {
        let renders = Renders()
        let log = Log()

        func tree(_ value: Int) -> Node {
            VStack { Label("\(value)") }
                .onChanged(value) { log.lines.append("fired") }
                .body
        }

        renders.render(tree(1))
        renders.render(tree(1))
        renders.render(tree(1))

        XCTAssertTrue(log.lines.isEmpty, "the value never moved and the handler ran anyway")
    }

    func testTheFirstRenderNeverFires() {
        let renders = Renders()
        let log = Log()

        renders.render(
            VStack { Label("x") }
                .onChanged(7) { log.lines.append("fired") }
                .body)

        XCTAssertTrue(log.lines.isEmpty,
            "a view appearing is not a value changing - that is .onLoaded's job")
    }

    func testTheHandlerGetsTheOldAndTheNewValue() {
        let renders = Renders()
        let log = Log()

        func tree(_ value: Int) -> Node {
            VStack { Label("\(value)") }
                .onChanged(value) { old, new in log.lines.append("\(old) -> \(new)") }
                .body
        }

        renders.render(tree(3))
        renders.render(tree(8))

        XCTAssertEqual(log.lines, ["3 -> 8"])
    }

    func testEachWatchAnswersForItsOwnValue() {
        let renders = Renders()
        let log = Log()

        func tree(a: Int, b: String) -> Node {
            VStack { Label(b) }
                .onChanged(a) { log.lines.append("a") }
                .onChanged(b) { log.lines.append("b") }
                .body
        }

        renders.render(tree(a: 1, b: "x"))
        renders.render(tree(a: 1, b: "y"))
        renders.render(tree(a: 2, b: "y"))

        XCTAssertEqual(log.lines, ["b", "a"],
            "two watches on one view answered for each other's values")
    }

    // MARK: - When it starts over instead

    func testAReplacedElementStartsOver() {
        let renders = Renders()
        let log = Log()

        renders.render(
            VStack { Label("x") }.onChanged(1) { log.lines.append("fired") }.body)

        // A different MAUI type at the same position replaces the control -
        // and a replaced element has nothing to have changed FROM.
        renders.render(
            HStack { Label("x") }.onChanged(2) { log.lines.append("fired") }.body)

        XCTAssertTrue(log.lines.isEmpty, "a replaced element fired as though it continued")
    }

    func testADifferentCountOfWatchesStartsOver() {
        let renders = Renders()
        let log = Log()

        renders.render(
            VStack { Label("x") }
                .onChanged(1) { log.lines.append("first") }
                .body)

        // An `.onChanged` written under an `if` appears and moves every slot
        // after it: the safe reading is "different watches", not "all changed".
        renders.render(
            VStack { Label("x") }
                .onChanged("extra") { log.lines.append("extra") }
                .onChanged(2) { log.lines.append("first") }
                .body)

        XCTAssertTrue(log.lines.isEmpty,
            "a changed number of watches was read as the values changing")
    }

    func testAChangedValueTypeStartsOver() {
        let renders = Renders()
        let log = Log()

        renders.render(
            VStack { Label("x") }.onChanged(1) { log.lines.append("fired") }.body)
        renders.render(
            VStack { Label("x") }.onChanged("1") { log.lines.append("fired") }.body)

        XCTAssertTrue(log.lines.isEmpty,
            "a slot that changed its value type fired instead of starting over")
    }

    // MARK: - Where it can be written

    func testAWatchOnAComposedViewSurvivesTheExpansion() {
        let renders = Renders()
        let log = Log()

        struct Panel: ContentView {
            var content: Element { Label("panel") }
        }

        func tree(_ value: Int) -> Node {
            VStack {
                Panel().onChanged(value) { log.lines.append("fired") }
            }.body
        }

        renders.render(tree(1))
        renders.render(tree(2))

        XCTAssertEqual(log.lines, ["fired"],
            "a watch written on a composed view was lost when the placeholder expanded")
    }

    func testAWatchInsideAContentGetterSeesItsOwnStateMove() {
        let renders = Renders()
        let log = Log()
        let view = Watcher(log: log)

        renders.render(Node(type: "Window", children: [view.body]))
        renders.render(Node(type: "Window", children: [view.body]))

        XCTAssertTrue(log.lines.isEmpty, "nothing moved yet")

        // The state the watch reads is on the view; a render after the write
        // carries the new value against the kept one.
        view.count = 5
        renders.render(Node(type: "Window", children: [view.body]))

        XCTAssertEqual(log.lines, ["moved"])
    }

    // MARK: - What the handler may do

    func testAHandlerThatWritesStateAsksForTheNextRender() {
        let renders = Renders()
        let echo = State(0)

        func tree(_ value: Int) -> Node {
            VStack { Label("\(value)") }
                .onChanged(value) { _, new in echo.wrappedValue = new }
                .body
        }

        renders.render(tree(1))
        Renderer.shared.clearInvalidation()

        renders.render(tree(9))

        XCTAssertEqual(echo.wrappedValue, 9)
        XCTAssertFalse(Renderer.shared.pendingChanges.isEmpty, """
            the handler's state write was swallowed by the render that fired it \
            - it must land AFTER the render's bookkeeping clears, so it asks for \
            the next one. See Core/Changes.swift.
            """)

        Renderer.shared.clearInvalidation()
    }

    func testAChangeIsReportedOnce() {
        let renders = Renders()
        let log = Log()

        func tree(_ value: Int) -> Node {
            VStack { Label("\(value)") }
                .onChanged(value) { log.lines.append("fired") }
                .body
        }

        renders.render(tree(1))
        renders.render(tree(2))
        renders.render(tree(2))
        renders.render(tree(2))

        XCTAssertEqual(log.lines, ["fired"],
            "one change fired more than once - the taken list was not cleared")
    }

    // MARK: - Interplay with the walks

    func testAWatchUnderAMemoFollowsItsToken() {
        let renders = Renders()
        let log = Log()

        func tree(item: String, watched: Int) -> Node {
            VStack {
                VStack { Label(item) }
                    .onChanged(watched) { log.lines.append("fired") }
                    .memoized(by: "\(item)|\(watched)")
            }.body
        }

        renders.render(tree(item: "a", watched: 1))

        // The token is unchanged, so the subtree is not built: no fresh value
        // was computed, and nothing compares - which is the memo's promise,
        // "everything this view shows comes from these inputs".
        renders.render(tree(item: "a", watched: 1))
        XCTAssertTrue(log.lines.isEmpty)

        // The token moved, the subtree is built again, and the watch compares
        // the fresh value against the kept one.
        renders.render(tree(item: "a", watched: 2))
        XCTAssertEqual(log.lines, ["fired"])
    }

    func testACleanWalkLeavesWatchesAlone() {
        let renders = Renders()
        let log = Log()
        let view = Watcher(log: log)

        renders.render(Node(type: "Window", children: [view.body]))

        // A clean walk builds nothing, so no fresh values exist to compare -
        // and a watch must not fire from a walk that computed nothing.
        renders.revisit(changed: [])

        XCTAssertTrue(log.lines.isEmpty, "a clean walk fired a watch without a fresh value")
    }

    // MARK: - Animations

    /// The one road an animation has INTO `.onChanged`, pinned end to end.
    ///
    /// An animation writes the CONTROL, never the tree, so a watch cannot see
    /// it directly - but a property the tree LISTENS to (`.width($w)`,
    /// `.height($h)`, `.scrollY($y)`) is reported back as it moves, the report
    /// writes the binding, the binding writes the state, and the watch hears
    /// the state: report by report while the animation runs, and the last
    /// report carries the value it ended on. This test stands in for the host
    /// exactly as the C# side behaves - a `widthChanged` report with the new
    /// value - so what it pins is everything on this side of that report.
    func testAReportedPropertyReachesAWatchThroughItsBinding() {
        let renders = Renders()
        let log = Log()
        let width = State(0.0)

        func tree() -> Node {
            VStack {
                Label("panel").width(width.projectedValue)
            }
            .onChanged(width.wrappedValue) { old, new in log.lines.append("\(old) -> \(new)") }
            .body
        }

        let patch = renders.render(tree())
        let id = patch.children.first?.events?["widthChanged"] ?? -1

        // What the host sends when a layout - an animated one included -
        // settles the width. The binding writes the state; nothing fires yet,
        // because no render has compared anything.
        renders.fire(id, with: [.number(250)])
        XCTAssertEqual(width.wrappedValue, 250)
        XCTAssertTrue(log.lines.isEmpty, "the watch fired before any render compared")

        renders.render(tree())

        XCTAssertEqual(log.lines, ["0.0 -> 250.0"],
            "a reported property did not reach the watch through its binding")

        Renderer.shared.clearInvalidation()
    }

    /// THE OTHER HALF OF EACH PAIR, which nothing named until a guard asked.
    ///
    /// `.width($w)` had a test and `.height($h)` did not; `.scrollY($y)` had one
    /// and `.scrollX($x)` did not. Both missing halves have a C# arm that ran in
    /// no test at all, and neither was visible to `testEveryModifierIsExercised`
    /// - an event modifier writes no property. See
    /// `testEveryEventModifierIsExercised`, which is what found them.
    func testTheSecondHalfOfEachReportedPairReachesItsBinding() {
        let renders = Renders()
        let height = State(0.0)
        let x = State(0.0)

        func tree() -> Node {
            VStack {
                Label("panel").height(height.projectedValue)

                ScrollView {
                    Label("wide")
                }
                .scrollX(x.projectedValue)
            }
            .body
        }

        let patch = renders.render(tree())
        let panel = patch.children.first
        let scroller = patch.children.last

        renders.fire(panel?.events?["heightChanged"] ?? -1, with: [.number(64)])
        renders.fire(scroller?.events?["scrollXChanged"] ?? -1, with: [.number(120)])

        XCTAssertEqual(height.wrappedValue, 64, "a reported height did not reach its binding")
        XCTAssertEqual(x.wrappedValue, 120, "a reported horizontal offset did not reach its binding")

        Renderer.shared.clearInvalidation()
    }

    /// The road OUT: a change handler may animate, and may await the answer.
    ///
    /// The message carrying the changed value is packed before the handler is
    /// queued - see Core/Changes.swift - so the act is asked for against an
    /// interface already showing the change. The handler then resumes with the
    /// act's own answer, exactly as a button's handler would.
    func testAChangeHandlerMayAwaitAnAct() async throws {
        let renders = Renders()
        let card = ControlState<Label>()
        let finished = State(false)

        func tree(_ value: Int) -> Node {
            VStack { Label("\(value)").id("card").assign(card) }
                .onChanged(value) { finished.wrappedValue = try await card.focus() }
                .body
        }

        _ = Renderer.shared.takeCommandsWire()
        renders.render(tree(1))
        renders.render(tree(2))

        // The handler ran up to its await and the act is on the queue, named
        // and addressed the way every act is.
        let acts = drainedActs()
        XCTAssertEqual(acts.first?.name, "focus")
        XCTAssertEqual(Array(acts.first?.arguments.prefix(1) ?? []), [.string("card")])

        // The host reports the view took the focus; the handler resumes and
        // writes what it was told.
        let completion = try XCTUnwrap(acts.compactMap(\.completion).first)

        ReplyBuffer.current = .finished([.bool(true)])
        if Renderer.shared.dispatch(completion) { _ = await settle() }

        XCTAssertTrue(finished.wrappedValue,
            "the handler never resumed with the animation's answer")

        Renderer.shared.clearInvalidation()
    }

    func testAWatchFiresOnTheCleanWalkWhenItsStateMoved() {
        let renders = Renders()
        let log = Log()
        let view = Watcher(log: log)

        renders.render(Node(type: "Window", children: [view.body]))

        // The tracked path, which is what a slider or an entry actually takes:
        // the write names its storage, the walk rebuilds just that view from
        // its placeholder, and the fresh value is compared against the kept
        // one.
        Renderer.shared.clearInvalidation()
        view.count = 5

        renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(log.lines, ["moved"],
            "the clean walk rebuilt the view and did not compare its watch")

        Renderer.shared.clearInvalidation()
    }
}
