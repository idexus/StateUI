// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI

/// A layout engine on a bench: rendered, told its room as the host tells it, and turned frame by frame on a display
/// clock of its own, so two turns in one test are two instants.
@MainActor
final class LayoutBench {
    /// Where the display clock stands.
    private var turned = 0.0

    /// One cycle of the display's board.
    func cycle() {
        turned += 16
        _ = Renderer.shared.board(for: .display).cycle(now: turned, reducesMotion: false)
    }

    /// One frame as the host runs it: the board's cycle, and what it wrote read out, so a report after it lands.
    func frame() {
        turned += 16
        _ = HostBoundary.cycle(.display, now: turned, reducesMotion: false)
    }

    /// The hand over the layout `tree` describes, as a host reports it - its phase, how far it moved what is under
    /// it since the last report, and the speed it lets go at, per second - and a cycle after it.
    func hand(
        _ renders: Renders, _ tree: () -> Node, _ phase: GesturePhase, moved: Point = .zero, speed: Point = .zero,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        // The whole description: a patch says nothing of a handler that did not change.
        guard let heard = renders.renderFromScratch(tree()).first(.layoutEngine)?.events?[.handMoved] else {
            return XCTFail("the layout hears no hand", file: file, line: line)
        }

        XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(phase, moved, speed)), file: file, line: line)
        cycle()
    }

    /// A wheel's notches over the layout `tree` describes, as a host reports them - across and down, the way they move
    /// what is under the hand - and a cycle after them.
    func step(
        _ renders: Renders, _ tree: () -> Node, _ notches: Point, file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let heard = renders.renderFromScratch(tree()).first(.layoutEngine)?.events?[.handStepped] else {
            return XCTFail("the layout hears no wheel's notch", file: file, line: line)
        }

        XCTAssertTrue(renders.fire(heard, with: MemberValues.encode(notches)), file: file, line: line)
        cycle()
    }

    /// Renders `tree`, feeds the layout the room `room` as the host does, and turns the board until the arithmetic
    /// has answered: the run of placements the layout's own area carries.
    func laid(
        _ renders: Renders, _ tree: () -> Node, room: Rect = Rect(10, 20, 300, 200),
        file: StaticString = #filePath, line: UInt = #line
    ) -> (patch: HostPatch, run: [Placement]) {
        let patch = renders.render(tree())

        guard let layout = patch.first(.layoutEngine),
              let fed = layout.driven?[.frame]?.state,
              let placed = layout.driven?[.area]?.state
        else {
            XCTFail("the layout is placed by no number", file: file, line: line)
            return (patch, [])
        }

        // THE FIRST CYCLE OF ALL LATCHES rather than runs, so the room is fed after it.
        cycle()
        moved(fed, to: [room.x, room.y, room.width, room.height])
        cycle()

        return (patch, standing(placed, as: PlacedRun.self)?.placements ?? [])
    }
}

extension HostPatch {
    /// The first patch of a kind, this one or however deep below it.
    func first(_ type: NodeType) -> HostPatch? {
        subtree.first { $0.type == type }
    }
}
