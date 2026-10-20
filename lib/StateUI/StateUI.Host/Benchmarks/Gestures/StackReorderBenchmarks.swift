// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A stack of two hundred rows turned one row over, again and again.
/// Design: docs/design/host/benchmarks.md#the-gestures
@MainActor
final class StackReorderBenchmarks: XCTestCase {
    /// TWO HUNDRED ROWS IN A NEW ORDER build the page again and no row, make and let go of no view, and arrange the
    /// stack once.
    func testTwoHundredRowsTurnedOver() throws {
        let bench = Bench(StackApplication())
        let turn = try XCTUnwrap(bench.runtime.tree.root?.first(id: .manual("turn"))?.handler(.clicked))

        let work = bench.measure("stack, two hundred rows turned one over", steps: 20) { _ in
            bench.runtime.dispatch(turn)
            bench.frame()
        }

        XCTAssertEqual(work, Work(
            renders: 20, built: 40, walks: 0, texts: 0, made: 0, applied: 100, arranged: 0, presented: 0,
            placed: 0, left: 0))
    }
}

private struct StackApplication: Application {
    var body: some Scene {
        WindowGroup { RowsPage() }
    }
}

/// Two hundred rows, the first put last at a click.
private struct RowsPage: View {
    @State private var rows = Array(0..<200)

    var body: some View {
        VStack {
            Button("Turn").onClicked { rows.append(rows.removeFirst()) }.id("turn")
            ForEach(rows, id: \.self) { number in
                Row(number: number)
            }
        }
    }
}

/// One row: its number and its triple.
private struct Row: View {
    let number: Int

    var body: some View {
        HStack {
            Text("Row \(number)")
            Spacer()
            Text("\(number * 3)")
        }
    }
}
