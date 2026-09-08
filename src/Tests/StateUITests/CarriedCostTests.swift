// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT A WRITE COSTS, once the host carries a state.
//
// A `@State` the host carries is written on every frame something moves - a
// finger, an engine - and each write takes two roads at once: the board's,
// which lays the lanes and bumps the stamp, and the renderer's, which asks
// whether anybody read the state at build and refuses when nobody did. The
// second road is what the board's own write does not take, and this file is
// what says what it costs, in nanoseconds per write, beside the write it stands next to.
//
// Printed rather than asserted: a number that depends on the machine is not
// a contract, and the comparison it exists for is read off the log.

import Dispatch
import XCTest
@testable import StateUI

final class CarriedCostTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// Nanoseconds per call, over enough calls to be worth quoting.
    private func perCall(_ count: Int, _ body: () -> Void) -> Double {
        let started = DispatchTime.now().uptimeNanoseconds

        for _ in 0..<count { body() }

        return Double(DispatchTime.now().uptimeNanoseconds - started) / Double(count)
    }

    /// A write to a state nobody reads, carried and not - the two roads a
    /// moving value's write takes here, each measured alone.
    func testWhatAWriteCosts() {
        let count = 200_000

        // A plain state nobody reads: the renderer's road alone.
        let plain = State(0.0)
        var tick = 0.0
        let plainWrite = perCall(count) { tick += 1; plain.wrappedValue = tick }

        // A carried state nobody reads: the board's road AND the renderer's.
        let carried = State(0.0)
        _ = carried.image
        tick = 0
        let carriedWrite = perCall(count) { tick += 1; carried.wrappedValue = tick }

        // The board's road alone, for the comparison.
        let image = carried.image
        let board = Renderer.shared.board(of: image)
        tick = 0
        let boardWrite = perCall(count) {
            tick += 1
            board.write(StateImage.bytes(of: .lanes([tick])), to: image)
        }

        // And a read of each, which is what an engine does on its side.
        let plainRead = perCall(count) { _ = plain.wrappedValue }
        let carriedRead = perCall(count) { _ = carried.wrappedValue }

        print("""

            COST PER CALL (ns), \(count) calls each:
              plain @State write, nobody reads      \(Int(plainWrite))
              carried @State write, nobody reads    \(Int(carriedWrite))
              the board's write alone               \(Int(boardWrite))
              plain @State read                     \(Int(plainRead))
              carried @State read                   \(Int(carriedRead))
              refused by the renderer               \(Renderer.shared.refusedWrites)

            """)

        XCTAssertGreaterThan(Renderer.shared.refusedWrites, 0, "every write was refused - nobody read")
    }

    /// The whole of a frame's work for one carried value written by an engine:
    /// a write, a cycle that latches and runs the engine, and the read-out.
    func testWhatAFrameCosts() {
        let value = State(0.0)
        let reading = State("")
        _ = value.image
        _ = reading.image
        let board = Renderer.shared.board(of: value.image)

        let renders = Renders()
        renders.render(
            Label("frame")
                .engine(following: value.projectedValue) { _ in
                    reading.wrappedValue = "\(Int(value.wrappedValue))"
                }
                .body)

        board.cycle(now: 0, reducesMotion: false)

        let frames = 5_000
        var now = 16.0
        let perFrame = perCall(frames) {
            value.wrappedValue += 1
            board.cycle(now: now, reducesMotion: false)
            _ = board.dirty()
            now += 16
        }

        print("""

            ONE FRAME, one carried value written, one engine writing a caption:
              \(Int(perFrame)) ns a frame over \(frames) frames
              renders asked for: \(Renderer.shared.pendingChanges.count)  refused: \(Renderer.shared.refusedWrites)

            """)

        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty, "nothing read either state at build")
    }
}
