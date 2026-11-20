// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A layout's run moving its views has whoever reads a frame say where it stands again, whatever moved the run: a
/// cycle that stirred the layout, or a frame of its parameters' way, asked with no cycle of the core.
/// Design: docs/design/host/layout.md#asked-in-the-hosts-frame
@MainActor
final class ProgramFrameReadersTests: XCTestCase {
    private let bench = LayoutBench()

    /// A view whose frame is read.
    private final class Reader: FrameReporter {
        func reportFrame() {}
    }

    /// A FRAME OF THE PARAMETERS' WAY HAS A FRAME'S READER SAY WHERE IT STANDS: each frame the run moved its views
    /// something was laid out to say, and a run at rest says nothing more.
    func testAFrameOfTheParametersWayTellsWhoeverReadsAFrame() throws {
        let phase = State(wrappedValue: 0.0, motion: .eased(.milliseconds(400)))
        func tree() -> Node {
            MotionLayout([0, 1], parameters: phase.projectedValue) { Text("\($0)") } placements: { _, at in
                (0..<2).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 10, height: 10)) }
            }
            .layoutBodies(LayoutBody.none)
            .node
        }
        bench.laid(tree)
        let runtime = try XCTUnwrap(bench.runtime)
        let reader = Reader()
        runtime.frames.follow(reader, of: try XCTUnwrap(bench.layout), reads: true)
        XCTAssertTrue(runtime.frames.reportLaidOut(), "read from now on")
        bench.cycle()
        XCTAssertFalse(runtime.frames.reportLaidOut(), "the run stands: nothing to say")

        phase.wrappedValue = 1
        bench.cycle()
        runtime.frames.reportLaidOut()
        for frame in 1...4 {
            let before = bench.placed[0].bounds.x
            bench.cycle()
            XCTAssertLessThan(bench.placed[0].bounds.x, before, "frame \(frame) of the way moved the views")
            XCTAssertTrue(runtime.frames.reportLaidOut(), "and whoever reads a frame says it (frame \(frame))")
        }

        bench.frames(60)
        XCTAssertEqual(bench.placed[0].bounds.x, -100, accuracy: 0.001, "at rest")
        runtime.frames.reportLaidOut()
        bench.cycle()
        XCTAssertFalse(runtime.frames.reportLaidOut(), "nothing moved: nothing to say")
    }
}
