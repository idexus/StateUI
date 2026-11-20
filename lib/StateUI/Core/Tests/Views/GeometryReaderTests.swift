// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.onFrameChanged` hands its handler the four values its space means, out of
// the one eight-number report the host sends - and a GeometryReader builds its
// content FROM that measurement, holding it in a @State of its own. See
// GeometryReader.swift.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class GeometryReaderTests: XCTestCase {
    /// What the last handler run was given, shared with the assert the way a
    /// state box would be.
    private final class Heard: @unchecked Sendable {
        var frames: [Rect] = []
    }

    /// One report, as a host composes it: parent x, y, width, height,
    /// then the origin in the window, then in the safe area.
    private let payload: [PropValue] = [.numbers([10, 20, 300, 400, 110, 220, 110, 176])]

    // MARK: - The modifier

    private func frame(in space: CoordinateSpace) -> Rect? {
        let renders = Renders()
        let heard = Heard()

        let patch = renders.render(
            VStack {
                Text("content")
            }
            .onFrameChanged(in: space) { heard.frames.append($0) }
            .node)

        renders.fire(patch.events?[.layoutFrameChanged] ?? -1, with: payload)
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
                .node)

        renders.fire(patch.events?[.layoutFrameChanged] ?? -1, with: payload)

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
                .node)

        renders.fire(patch.events?[.layoutFrameChanged] ?? -1, with: payload)

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
                .node)

        let id = patch.events?[.layoutFrameChanged] ?? -1

        renders.fire(id, with: [.numbers([10, 20, 300, 400, 110, 220, 110, 176])])

        // What a scroll sends: the same parent frame, a moved window origin.
        renders.fire(id, with: [.numbers([10, 20, 300, 400, 110, 470, 110, 426])])

        XCTAssertEqual(parents.frames, [Rect(10, 20, 300, 400)],
            "the parent-space handler heard a scroll that never changed its answer")
        XCTAssertEqual(windows.frames, [Rect(110, 220, 300, 400), Rect(110, 470, 300, 400)])
    }

    // MARK: - The stage

    /// EACH STAGE IS AN EVENT OF ITS OWN: a handler at the layout stage hears where the layout puts the view and
    /// never where it is drawn, and a handler at the presentation stage the other way round.
    func testEachStageHearsItsOwnEvent() {
        let renders = Renders()
        let placed = Heard()
        let drawn = Heard()

        let patch = renders.render(
            VStack {}
                .onFrameChanged { placed.frames.append($0) }
                .onFrameChanged(stage: .presentation) { drawn.frames.append($0) }
                .node)

        renders.fire(patch.events?[.layoutFrameChanged] ?? -1, with: payload)
        XCTAssertEqual(placed.frames, [Rect(10, 20, 300, 400)])
        XCTAssertTrue(drawn.frames.isEmpty, "the layout's frame reached the presentation's handler")

        renders.fire(patch.events?[.presentationFrameChanged] ?? -1, with: [.numbers([14, 20, 300, 400, 114, 220, 114, 176])])
        XCTAssertEqual(drawn.frames, [Rect(14, 20, 300, 400)])
        XCTAssertEqual(placed.frames.count, 1, "a step of the way is no frame of the layout's")
    }

    /// A STAGE NOBODY READS IS NOT ASKED OF THE HOST: the view names the event of the stage it reads, alone.
    func testAStageNotReadIsNotAsked() {
        let drawn = Renders().render(VStack {}.onFrameChanged(stage: .presentation) { _ in }.node)
        XCTAssertNotNil(drawn.events?[.presentationFrameChanged])
        XCTAssertNil(drawn.events?[.layoutFrameChanged])

        let placed = Renders().render(VStack {}.onFrameChanged { _ in }.node)
        XCTAssertNotNil(placed.events?[.layoutFrameChanged], "the layout's stage unless said")
        XCTAssertNil(placed.events?[.presentationFrameChanged])
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
                .node)

        let id = patch.events?[.layoutFrameChanged] ?? -1

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
        let reader = reading { _ = width.wrappedValue }
        defer { _ = reader }

        let patch = renders.render(
            VStack {}
                .onFrameChanged { width.wrappedValue = $0.width }
                .node)

        Renderer.shared.clearInvalidation()
        renders.fire(patch.events?[.layoutFrameChanged] ?? -1, with: payload)

        XCTAssertEqual(width.wrappedValue, 300)
        XCTAssertFalse(Renderer.shared.pendingChanges.isEmpty,
            "the measurement's write did not ask for a render")

        Renderer.shared.clearInvalidation()
    }

    // MARK: - The container

    /// A GeometryReader's content is built FROM the measurement: nothing before
    /// the first report - no content laid out at no size, to grow when the
    /// frame arrives - the measured frame after, the closure running because
    /// the report wrote the reader's own `@State`.
    func testAReadersContentIsBuiltFromTheMeasurement() {
        let renders = Renders()

        func tree() -> Node {
            Node(type: "Window", children: [
                VStack {
                    GeometryReader { frame in
                        Text("\(Int(frame.width)) wide")
                    }
                }.node,
            ])
        }

        let first = renders.render(tree())

        // Before any report the reader holds nothing.
        let grid = first.children.first?.children.first
        XCTAssertEqual(grid?.children.count, 0, "content built before its frame was known")

        Renderer.shared.clearInvalidation()
        renders.fire(grid?.events?[.layoutFrameChanged] ?? -1, with: payload)

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
                    GeometryReader { frame in
                        Text("\(Int(frame.width)) wide")
                    }

                    Text("sibling")
                }.node,
            ])
        }

        let first = renders.render(tree())
        let grid = first.children.first?.children.first

        Renderer.shared.clearInvalidation()
        renders.fire(grid?.events?[.layoutFrameChanged] ?? -1, with: payload)

        // The tracked path, exactly what the host takes after the handler's
        // write: only the views whose recorded reads moved are built again.
        let patch = renders.revisit(changed: Renderer.shared.pendingChanges)

        func names(in patch: HostPatch) -> [NodeType] {
            [patch.type] + patch.children.flatMap { names(in: $0) }
        }

        let touched = names(in: patch)
        XCTAssertTrue(touched.contains("Text"), "the reader's content was not rebuilt")
        XCTAssertFalse(
            patch.children.first?.children.contains { $0.props["text"] == .string("sibling") } ?? false,
            "the sibling was rebuilt for a measurement it never read")

        Renderer.shared.clearInvalidation()
    }

    /// A scroll moves the window origin and not the parent frame: a reader in its parent's space builds its
    /// content once for the frame, never again for each scrolled report.
    func testAScrollMovingAReaderBuildsItsContentOnce() {
        let renders = Renders()
        let built = Heard()

        func shown(_ frame: Rect) -> Text {
            built.frames.append(frame)
            return Text("\(Int(frame.width)) wide")
        }

        func tree() -> Node {
            Node(type: "Window", children: [VStack { GeometryReader { frame in shown(frame) } }.node])
        }

        let grid = renders.render(tree()).children.first?.children.first
        let id = grid?.events?[.layoutFrameChanged] ?? -1

        Renderer.shared.clearInvalidation()
        renders.fire(id, with: payload)
        renders.revisit(changed: Renderer.shared.pendingChanges)

        for scrolled in 1...5 {
            Renderer.shared.clearInvalidation()
            let y = 220 - Double(scrolled * 40)
            renders.fire(id, with: [.numbers([10, 20, 300, 400, 110, y, 110, y - 44])])
            renders.revisit(changed: Renderer.shared.pendingChanges)
        }

        XCTAssertEqual(built.frames.map(\.width), [300], "built for the frame once, and for no scroll")
        Renderer.shared.clearInvalidation()
    }
}
