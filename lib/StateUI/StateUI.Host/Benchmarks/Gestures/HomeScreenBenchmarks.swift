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
        let board = try bench.element(.layoutEngine)
        let cell = Point((bench.room.width - 16) / 4, (bench.room.height - 16) / 5)

        bench.hand(.began, on: board, at: Point(8 + cell.x / 2, 8 + cell.y / 2))
        bench.frames(for: 600)
        let work = bench.measure("home screen, a held icon moved a cell", steps: 12) { step in
            let across = step % 4 == 3
            bench.hand(.changed, on: board, moved: across ? Point(-cell.x * 3, cell.y) : Point(cell.x, 0))
            bench.frames(for: 100)
        }
        bench.hand(.ended, on: board, speed: Point(0, 0))
        bench.frames(for: 1_000)

        XCTAssertEqual(work, Work(
            renders: 12, built: 36, walks: 12, texts: 576, made: 0, applied: 60, arranged: 0, presented: 92,
            placed: 4_416, left: 0))
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
    @State private var board = 0.0
    @State private var lifted: String?

    var body: some View {
        let count = icons.count
        return LayoutEngine(icons, id: \.self) { icon in
            HomeTile(name: icon, lifted: lifted == icon)
        } placements: { room, board in
            (0..<count).map { Self.place($0, board, room) }
        }
        .phase($board)
        .axis(\.self, input: .pages(.horizontal), range: 0...2, keyframes: .every(1), snaps: .every(1))
        .itemDrag(begins: .held)
        .onItemDragged { drag in
            switch drag.phase {
            case .began: lifted = drag.item
            case .ended, .cancelled: lifted = nil
            default: move(drag.item, to: Self.slot(at: drag.at, in: drag.room, board: board))
            }
        }
        .motion(.spring(response: .milliseconds(380), damping: 0.86))
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
            Rect(x + (width - 84) / 2, y + (height - 96) / 2, 84, 96), transform: .scale(min(width / 84, height / 96)))
    }
}

/// One icon: a glyph on a disc on a rounded square, and its name; larger while held.
private struct HomeTile: View {
    let name: String
    let lifted: Bool

    var body: some View {
        VStack {
            ZStack {
                Rectangle(Color("#2563EB"))
                    .cornerRadius(14)
                Rectangle(.white)
                    .cornerRadius(21)
                    .opacity(0.3)
                    .width(42)
                    .height(42)
                Image(.icon(.star))
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
    }
}
