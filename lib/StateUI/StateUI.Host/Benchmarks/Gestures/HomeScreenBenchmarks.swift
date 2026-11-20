// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A home screen of 48 icons on boards of twenty, an icon held and moved across them.
/// Design: docs/design/host/benchmarks.md#the-gestures
@MainActor
final class HomeScreenBenchmarks: XCTestCase {
    /// AN ICON HELD AND MOVED CELL BY CELL builds the board again and no icon, and the icons it passes travel to their
    /// new places on the frames.
    func testAHeldIconMovedAcrossTheBoard() throws {
        let bench = Bench(HomeApplication())
        // The hand takes the first icon, which says its own drag in its body: its holder stays carried.
        let icon = try XCTUnwrap(bench.element(.motionLayout).children.first?.children.first)
        let cell = Point(x: (bench.room.width - 16) / 4, y: (bench.room.height - 16) / 5)

        bench.hand(.began, on: icon, at: Point(x: cell.x / 2, y: cell.y / 2))
        bench.frames(for: 600)
        let work = bench.measure("home screen, a held icon moved a cell", steps: 12) { step in
            let across = step % 4 == 3
            bench.hand(.changed, on: icon, moved: across ? Point(x: -cell.x * 3, y: cell.y) : Point(x: cell.x, y: 0))
            bench.frames(for: 100)
        }
        bench.hand(.ended, on: icon, speed: Point(x: 0, y: 0))
        bench.frames(for: 1_000)

        XCTAssertEqual(work, Work(
            renders: 12, built: 36, walks: 12, texts: 0, made: 0, applied: 60, arranged: 0, presented: 80,
            placed: 3_840, left: 0))
    }
}

private struct HomeApplication: Application {
    var body: some Scene {
        WindowGroup { HomeBoard() }
    }
}

/// The icons, a board of twenty in four columns a board, the held one lifted.
private struct HomeBoard: View {
    @State private var icons = (0..<48).map { "Icon \($0)" }
    @State(motion: .spring(response: .milliseconds(380), damping: 0.86)) private var board = 0.0
    @State private var lifted: String?

    var body: some View {
        let count = icons.count
        return MotionLayout(icons, parameters: $board) { icon in
            HomeTile(name: icon, lifted: lifted == icon)
        } placements: { context, board in
            (0..<count).map { Self.place($0, board, context.bounds) }
        }
        .axis(range: 0...2, keyframes: .every(1))
        .interaction(
            .value($board, input: .swipe(.horizontal, unit: .containerLength)).reversed(true).range(0...2).snaps(.every(1))
                .release(.projected(.eased(.milliseconds(400)))))
        .onItemDragged { drag in
            switch drag.phase {
            case .began: lifted = drag.id
            case .ended, .cancelled: lifted = nil
            default: move(drag.id, to: Self.slot(at: drag.at, in: drag.room, board: board))
            }
        }
    }

    private func move(_ icon: String, to slot: Int) {
        guard let from = icons.firstIndex(of: icon), from != slot else { return }
        icons.remove(at: from)
        icons.insert(icon, at: min(slot, icons.count))
    }

    /// The slot under `point` on the board in front.
    private static func slot(at point: Point, in room: Rect, board: Double) -> Int {
        let column = min(max(Int((point.x - 8) / ((room.width - 16) / 4)), 0), 3)
        let row = min(max(Int((point.y - 8) / ((room.height - 16) / 5)), 0), 4)
        return Int(board.rounded()) * 20 + row * 4 + column
    }

    /// Where the icon at `slot` stands: in its cell of its board, the boards a room's width apart.
    private static func place(_ slot: Int, _ board: Double, _ room: Rect) -> Placement {
        let (page, cell) = slot.quotientAndRemainder(dividingBy: 20)
        let (width, height) = ((room.width - 16) / 4, (room.height - 16) / 5)
        let x = (Double(page) - board) * room.width + 8 + Double(cell % 4) * width
        let y = 8 + Double(cell / 4) * height
        return Placement(
            Rect(x: x + (width - 84) / 2, y: y + (height - 96) / 2, width: 84, height: 96), transform: .scale(min(width / 84, height / 96)))
    }
}

/// One icon: a glyph on a disc on a rounded square, and its name; larger while held.
private struct HomeTile: View {
    let name: String
    let lifted: Bool

    var body: some View {
        VStack {
            ZStack {
                Rectangle()
                    .fill(Color(hex: 0x2563EB))
                    .cornerRadius(14)
                Rectangle()
                    .fill(.white)
                    .cornerRadius(21)
                    .opacity(0.3)
                    .width(42)
                    .height(42)
                Image(.platform(.star))
                    .width(26)
                    .height(26)
            }
            .width(60)
            .height(60)
            Text(name)
                .fontSize(12)
        }
        .spacing(6)
        .scale(lifted ? 1.18 : 1)
        .motion(.spring(response: .milliseconds(260), damping: 0.55), .transform)
        // Said in the tile's own body, so the board's holders are carried whole across its descriptions.
        .interaction(.drag(.both, begins: .longPress))
    }
}
