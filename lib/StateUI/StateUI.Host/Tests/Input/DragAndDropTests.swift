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

        XCTAssertEqual(try element("source", in: runtime).dragAndDrop, DragAndDrop(words: "Alpha", takesWords: false))
        XCTAssertEqual(try element("basket", in: runtime).dragAndDrop, DragAndDrop(words: nil, takesWords: true))
        XCTAssertEqual(try element("still", in: runtime).dragAndDrop, .none)
        XCTAssertEqual(runtime.tree.root?.takingDrops.first?.id, .manual("basket"), "the views a window's drag finds")
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

    func testAViewTakesTheDroppedFilesOfItsKinds() {
        let files = ["a.txt", "b.png", "c.TXT", "d"].map { ChosenFile(address: "/\($0)", name: $0) }
        let text = FileType("Text", extensions: ["txt"])

        XCTAssertEqual(DragAndDrop(words: nil, takesWords: false, fileTypes: [text]).taken(files).map(\.name), ["a.txt", "c.TXT"])
        XCTAssertEqual(DragAndDrop(words: nil, takesWords: false, fileTypes: []).taken(files), files, "any file")
        XCTAssertEqual(DragAndDrop.none.taken(files), [], "a view taking no files")
    }

    func testFilesDroppedOnAViewAreHeardByTheirKind() throws {
        let runtime = running()
        let shelf = try element("shelf", in: runtime)
        XCTAssertEqual(shelf.dragAndDrop.fileTypes, [FileType("Text", extensions: ["txt"])])

        shelf.hear(.dragOver, in: runtime)
        shelf.hear(.filesDropped([ChosenFile(address: "/photo.png", name: "photo.png")]), in: runtime)
        shelf.hear(.filesDropped(["note.txt", "photo.png"].map { ChosenFile(address: "/\($0)", name: $0) }), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(said, ["files note.txt"], "a file of its kind, none of another")
        XCTAssertEqual(runtime.tree.root?.takingDrops.map(\.id), [.manual("basket"), .manual("shelf")])
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
            Text("Shelf")
                .onDrop(files: [FileType("Text", extensions: ["txt"])]) { @MainActor files in
                    said.append("files " + files.map(\.name).joined(separator: " "))
                }
                .id("shelf")
        }
    }
}

private struct BasketApplication: Application {
    var body: some Scene { WindowGroup { BasketPage() } }
}
