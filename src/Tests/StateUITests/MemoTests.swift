// A memoized view is not built while its inputs are unchanged. These count the
// builds, because that is the only way to tell.

import XCTest
@testable import StateUI

private final class Builds {
    var count = 0
}

final class MemoTests: XCTestCase {
    /// A node standing in for a subtree, counting how often it is asked for.
    private func row(_ text: String, token: String, builds: Builds) -> Node {
        var node = Node(type: "Memoized", id: token)
        node.memo = Node.Memo(token: AnyHashable(text)) {
            builds.count += 1
            return label(text)
        }
        return node
    }

    func testAnUnchangedInputIsNotBuilt() {
        let renders = Renders()
        let builds = Builds()

        renders.render(stack([row("a", token: "a", builds: builds)], id: "root"))
        XCTAssertEqual(builds.count, 1, "built once, to say what it is")

        for _ in 0..<5 {
            renders.render(stack([row("a", token: "a", builds: builds)], id: "root"))
        }

        XCTAssertEqual(builds.count, 1, "five renders later, still built once")
    }

    func testAChangedInputIsBuiltAgain() {
        let renders = Renders()
        let builds = Builds()

        renders.render(stack([row("a", token: "a", builds: builds)], id: "root"))
        let patch = renders.render(stack([row("A", token: "a", builds: builds)], id: "root"))

        XCTAssertEqual(builds.count, 2)
        XCTAssertEqual(patch.child("a")?.props["text"], .string("A"))
    }

    func testMovingAMemoizedViewReportsOnlyItsPosition() {
        let renders = Renders()
        let builds = Builds()

        renders.render(stack([
            row("a", token: "a", builds: builds),
            row("b", token: "b", builds: builds),
        ], id: "root"))

        XCTAssertEqual(builds.count, 2)

        let patch = renders.render(stack([
            row("b", token: "b", builds: builds),
            row("a", token: "a", builds: builds),
        ], id: "root"))

        XCTAssertEqual(builds.count, 2, "swapping two rows builds neither")
        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.map(\.id), [.manual("b"), .manual("a")],
                       "the list itself says they swapped")
    }

    func testHandlersInsideAMemoizedViewGoOnWorking() {
        let renders = Renders()
        var taps = 0

        func tree() -> Node {
            var node = Node(type: "Memoized", id: "row")
            node.memo = Node.Memo(token: AnyHashable("unchanged")) {
                Node(type: "Button", events: ["clicked": { taps += 1 }])
            }
            return stack([node], id: "root")
        }

        let first = renders.render(tree())
        let id = first.child("row")!.child(.auto(3))?.events?["clicked"]
            ?? first.child("row")!.events?["clicked"]

        XCTAssertNotNil(id, "the button reported an id on the render that built it")

        // Renders that skip the subtree entirely.
        for _ in 0..<3 { renders.render(tree()) }

        XCTAssertTrue(renders.fire(id!), "a skipped subtree keeps its handlers registered")
        XCTAssertEqual(taps, 1)
    }

    /// A resync must describe the subtree the skip would have left out: the
    /// message replaces everything the host is showing, so anything absent
    /// from it is gone from the screen, unchanged token or not.
    func testAResyncDescribesWhatTheSkipWouldOmit() {
        let renders = Renders()
        let builds = Builds()

        renders.render(stack([row("a", token: "a", builds: builds)], id: "root"))

        let resync = renders.renderFromScratch(
            stack([row("a", token: "a", builds: builds)], id: "root"))

        XCTAssertEqual(
            resync.child("a")?.props["text"], .string("a"),
            "the complete message carries the memoized subtree in full")
        XCTAssertEqual(builds.count, 2, "described means built, this once")
    }
}
