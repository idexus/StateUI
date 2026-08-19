// `.onFrameChanged` hands its handler the four values its space means, out of
// the one eight-number report the host sends - and a FrameReader builds its
// content FROM that measurement, holding it in a @State of its own. See
// Views/FrameReader.swift.

import XCTest
@testable import StateUI

final class FrameReaderTests: XCTestCase {
    /// What the last handler run was given, shared with the assert the way a
    /// state box would be.
    private final class Heard: @unchecked Sendable {
        var frames: [Rect] = []
    }

    /// One report, as the C# side composes it: parent x, y, width, height,
    /// then the origin in the window, then in the safe area.
    private let payload: [PropValue] = [.numbers([10, 20, 300, 400, 110, 220, 110, 176])]

    // MARK: - The modifier

    private func frame(in space: CoordinateSpace) -> Rect? {
        let renders = Renders()
        let heard = Heard()

        let patch = renders.render(
            VStack {
                Label("content")
            }
            .onFrameChanged(in: space) { heard.frames.append($0) }
            .body)

        renders.fire(patch.events?["frameChanged"] ?? -1, with: payload)
        return heard.frames.last
    }

    func testTheParentSpaceIsTheFrameAsTheParentPlacedIt() {
        XCTAssertEqual(frame(in: .parent), Rect(10, 20, 300, 400))
    }

    func testTheGlobalSpaceMovesTheOriginToTheWindow() {
        XCTAssertEqual(frame(in: .global), Rect(110, 220, 300, 400))
    }

    func testTheSafeAreaSpaceMovesItPastTheInsets() {
        XCTAssertEqual(frame(in: .safeArea), Rect(110, 176, 300, 400))
    }

    func testTheDefaultSpaceIsTheParent() {
        let renders = Renders()
        let heard = Heard()

        let patch = renders.render(
            VStack {}
                .onFrameChanged { heard.frames.append($0) }
                .body)

        renders.fire(patch.events?["frameChanged"] ?? -1, with: payload)

        XCTAssertEqual(heard.frames.last, Rect(10, 20, 300, 400))
    }

    /// Two handlers on one view hear one report each, in writing order -
    /// `addHandler` runs a later handler BESIDE an earlier one.
    func testEachSpaceReportsToItsOwnHandler() {
        let renders = Renders()
        let heard = Heard()

        let patch = renders.render(
            VStack {}
                .onFrameChanged { heard.frames.append($0) }
                .onFrameChanged(in: .global) { heard.frames.append($0) }
                .body)

        renders.fire(patch.events?["frameChanged"] ?? -1, with: payload)

        XCTAssertEqual(heard.frames, [Rect(10, 20, 300, 400), Rect(110, 220, 300, 400)])
    }

    /// A scroll moves the window origin and nothing else - the report goes
    /// out, and each handler answers only for ITS space: the `.global` one
    /// hears the move, the `.parent` one hears nothing at all.
    func testAHandlerHearsOnlyItsOwnSpaceMove() {
        let renders = Renders()
        let parents = Heard()
        let windows = Heard()

        let patch = renders.render(
            VStack {}
                .onFrameChanged { parents.frames.append($0) }
                .onFrameChanged(in: .global) { windows.frames.append($0) }
                .body)

        let id = patch.events?["frameChanged"] ?? -1

        renders.fire(id, with: [.numbers([10, 20, 300, 400, 110, 220, 110, 176])])

        // What a scroll sends: the same parent frame, a moved window origin.
        renders.fire(id, with: [.numbers([10, 20, 300, 400, 110, 470, 110, 426])])

        XCTAssertEqual(parents.frames, [Rect(10, 20, 300, 400)],
            "the parent-space handler heard a scroll that never changed its answer")
        XCTAssertEqual(windows.frames, [Rect(110, 220, 300, 400), Rect(110, 470, 300, 400)])
    }

    /// The gesture payloads' rule, kept here too: a report this side cannot
    /// read is a version mismatch, not an event, and the handler stays out of
    /// it. Three ways it cannot read - no values, too few numbers, and a value
    /// of the wrong kind entirely.
    func testAPayloadItCannotReadLeavesTheHandlerAlone() {
        let renders = Renders()
        let heard = Heard()

        let patch = renders.render(
            VStack {}
                .onFrameChanged { heard.frames.append($0) }
                .body)

        let id = patch.events?["frameChanged"] ?? -1

        renders.fire(id, with: [])
        renders.fire(id, with: [.numbers([10, 20, 300, 400])])
        renders.fire(id, with: [.bool(true)])

        XCTAssertTrue(heard.frames.isEmpty, "an unreadable report reached the handler")
    }

    /// The handler is a handler: a `@State` write from one asks for a render,
    /// which is what lets the interface follow the measurement.
    func testTheHandlerMayWriteState() {
        let renders = Renders()
        let width = State(0.0)

        let patch = renders.render(
            VStack {}
                .onFrameChanged { width.wrappedValue = $0.width }
                .body)

        Renderer.shared.clearInvalidation()
        renders.fire(patch.events?["frameChanged"] ?? -1, with: payload)

        XCTAssertEqual(width.wrappedValue, 300)
        XCTAssertFalse(Renderer.shared.pendingChanges.isEmpty,
            "the measurement's write did not ask for a render")

        Renderer.shared.clearInvalidation()
    }

    // MARK: - The container

    /// A FrameReader's content is built FROM the measurement: zero before the
    /// first report, the measured frame after - the closure running again
    /// because the report wrote the reader's own `@State`.
    func testAReadersContentIsBuiltFromTheMeasurement() {
        let renders = Renders()

        func tree() -> Node {
            Node(type: "Window", children: [
                VStack {
                    FrameReader { frame in
                        Label("\(Int(frame.width)) wide")
                    }
                }.body,
            ])
        }

        let first = renders.render(tree())

        // Before any report the closure was handed a zero rectangle.
        let grid = first.children.first?.children.first
        XCTAssertEqual(grid?.children.first?.props["text"], .string("0 wide"))

        Renderer.shared.clearInvalidation()
        renders.fire(grid?.events?["frameChanged"] ?? -1, with: payload)

        // The report wrote the reader's @State; the next render builds the
        // content from the measured frame.
        let second = renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(second.children.first?.children.first?.children.first?.props["text"],
            .string("300 wide"),
            "the content did not follow the measurement")

        Renderer.shared.clearInvalidation()
    }

    /// The reason the container exists at all: the measurement lives in the
    /// READER's `@State`, so a settled frame rebuilds the reader's content and
    /// nothing else - a sibling is carried over untouched.
    func testAMeasurementRebuildsTheReaderAndNotItsSiblings() {
        let renders = Renders()

        func tree() -> Node {
            Node(type: "Window", children: [
                VStack {
                    FrameReader { frame in
                        Label("\(Int(frame.width)) wide")
                    }

                    Label("sibling")
                }.body,
            ])
        }

        let first = renders.render(tree())
        let grid = first.children.first?.children.first

        Renderer.shared.clearInvalidation()
        renders.fire(grid?.events?["frameChanged"] ?? -1, with: payload)

        // The tracked path, exactly what the host takes after the handler's
        // write: only the views whose recorded reads moved are built again.
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)

        func names(in patch: Patch) -> [NodeType] {
            [patch.type] + patch.children.flatMap { names(in: $0) }
        }

        let touched = names(in: patch)
        XCTAssertTrue(touched.contains("Label"), "the reader's content was not rebuilt")
        XCTAssertFalse(
            patch.children.first?.children.contains { $0.props["text"] == .string("sibling") } ?? false,
            "the sibling was rebuilt for a measurement it never read")

        Renderer.shared.clearInvalidation()
    }
}
