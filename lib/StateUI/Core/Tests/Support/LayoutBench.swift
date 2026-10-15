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

    /// Tells every frame reader in `tree` its room and renders again, until none stands untold - the scroller
    /// stands once its reader knows its room: the whole layout as it stands on screen.
    func stood(_ renders: Renders, _ tree: () -> Node) -> HostPatch {
        var told: Set<Int> = []
        _ = renders.render(tree())

        for _ in 0..<3 {
            // The whole description: a patch says nothing of a handler that did not change.
            let untold = renders.renderFromScratch(tree()).subtree
                .compactMap { $0.events?[.frameChanged] }
                .filter { !told.contains($0) }
            guard !untold.isEmpty else { break }

            for id in untold {
                XCTAssertTrue(renders.fire(id, with: [.numbers([0, 0, 300, 200, 0, 0, 0, 0])]))
                told.insert(id)
            }
            _ = renders.render(tree())
        }

        return renders.renderFromScratch(tree())
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
