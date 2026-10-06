// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A drag between views, the same on every host: what a view offers and takes, and a drag over a view that takes
/// drops told once as it comes, as it goes - never after a drop - and as it is let go, with its words.
@MainActor
final class DragAndDropTests: XCTestCase {
    func testAViewIsHeardOverOnceAndLeftOnlyBeforeADrop() {
        var target = DropTarget()

        XCTAssertTrue(target.over(), "a drag comes")
        XCTAssertFalse(target.over(), "and stays")
        XCTAssertTrue(target.left(), "and goes")
        XCTAssertFalse(target.left(), "gone once")
        XCTAssertTrue(target.over(), "it comes again")
        target.dropped()
        XCTAssertFalse(target.left(), "no leaving after a drop")
        XCTAssertFalse(target.left(), "a toolkit telling a leave a drop ended is heard by nobody")
    }

    func testAViewSaysWhatItOffersAndTakes() throws {
        let runtime = running()

        XCTAssertEqual(try element("source", in: runtime).dragAndDrop, DragAndDrop(words: "Alpha", takesDrops: false))
        XCTAssertEqual(try element("basket", in: runtime).dragAndDrop, DragAndDrop(words: nil, takesDrops: true))
        XCTAssertEqual(try element("still", in: runtime).dragAndDrop, .none)
    }

    func testADragOverAViewIsToldAsTheContractSays() throws {
        let runtime = running()
        let source = try element("source", in: runtime)
        let basket = try element("basket", in: runtime)

        source.hear(.dragStarted, in: runtime)
        for _ in 0..<3 { basket.hear(.dragOver, in: runtime) }
        basket.hear(.dragLeft, in: runtime)
        basket.hear(.dragOver, in: runtime)
        basket.hear(.dropped("Alpha"), in: runtime)
        basket.hear(.dragLeft, in: runtime)
        source.hear(.dragEnded, in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(said, ["starting", "over", "left", "over", "drop Alpha", "ended"])
    }

    private func running() -> HostRuntime {
        said = []
        stateUIUseApp(BasketApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        return runtime
    }

    private func element(_ id: String, in runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(id: .manual(id)))
    }
}

/// What the views heard, in order.
@MainActor private var said: [String] = []

private struct BasketPage: View {
    var body: some View {
        VStack {
            Text("Alpha")
                .draggable(text: "Alpha", onDragStarting: { @MainActor in said.append("starting") })
                .onDragEnded { @MainActor in said.append("ended") }
                .id("source")
            Text("Basket")
                .onDrop { @MainActor words in said.append("drop \(words)") }
                .onDragOver { @MainActor in said.append("over") }
                .onDragLeave { @MainActor in said.append("left") }
                .id("basket")
            Text("Still").id("still")
        }
    }
}

private struct BasketApplication: Application {
    var body: some Scene { WindowGroup { BasketPage() } }
}
