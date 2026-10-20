// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A list of a thousand rows scrolled from its top to its end, a screen of cells reused as a platform's collection
/// reuses them.
/// Design: docs/design/host/benchmarks.md#the-gestures
@MainActor
final class ItemsScrollBenchmarks: XCTestCase {
    /// A THOUSAND ROWS SCROLLED TWO A FRAME build each row about once, in batches the cells ask for ahead of them,
    /// and let go of the rows they leave behind.
    func testAThousandRowsScrolledToTheEnd() throws {
        let bench = Bench(ItemsApplication())
        let cells = try XCTUnwrap(bench.element(.itemsView).native as? CountedView).cells
        let list = try XCTUnwrap(cells)
        let identities = list.identities.filter(list.isItem)
        let screen = (0..<16).map { _ in Cell() }
        for (cell, identity) in zip(screen, identities) { list.hold(identity, in: cell) }
        bench.runtime.pump.turn()

        let work = bench.measure("items, a thousand rows scrolled two a frame", steps: (identities.count - 16) / 2) { step in
            for moved in 0..<2 {
                let first = step * 2 + moved
                let cell = screen[first % 16]
                list.endShowing(in: cell)
                list.hold(identities[first + 16], in: cell)
            }
            list.showing(identities[(step * 2 + 2)..<(step * 2 + 18)])
            bench.runtime.pump.turn()
            bench.frame()
        }

        XCTAssertEqual(work, Work(
            renders: 108, built: 5_495, walks: 5_279, texts: 10_342, made: 2_916, applied: 3_456, arranged: 0,
            presented: 0, placed: 0, left: 2_856))
    }
}

private struct ItemsApplication: Application {
    var body: some Scene {
        WindowGroup { NumbersPage() }
    }
}

/// N and N², a thousand times.
private struct NumbersPage: View {
    var body: some View {
        ItemsView(1...1_000) { number in
            HStack {
                Text("\(number)")
                    .fontSize(14)
                    .width(90)
                Text("\(number * number)")
                    .fontSize(13)
            }
            .spacing(12)
            .padding(horizontal: 14, vertical: 10)
        }
    }
}

/// A platform's cell, holding the entry it shows.
@MainActor
private final class Cell: ItemsHolding {
    var identity: String?
    var shown: MountedElement?

    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        shown = item
    }

    func letGo() {
        identity = nil
        shown = nil
    }
}
