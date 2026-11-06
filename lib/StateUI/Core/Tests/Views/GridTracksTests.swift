// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A grid's rows and columns are written as runs, each a length repeated as often as it says, and reach the host one
/// length a row or column.
@MainActor
final class GridTracksTests: XCTestCase {
    func testARunReachesTheHostOneLengthARowOrColumn() {
        let node = Grid {}
            .rows(.fill, .automatic(count: 2), .fill(count: 5), .fixed(80))
            .columns(.proportional(2, count: 2), .fixed(40, count: 3))
            .node

        let rows: [GridLength] = [.fill, .automatic, .automatic] + Array(repeating: .fill, count: 5) + [.fixed(80)]
        let columns: [GridLength] = [.proportional(2), .proportional(2), .fixed(40), .fixed(40), .fixed(40)]
        XCTAssertEqual(node.props[GridContract.rows.token], rows.propValue)
        XCTAssertEqual(node.props[GridContract.columns.token], columns.propValue)
    }

    func testACountBelowOneWritesNone() {
        let node = Grid {}.rows(.fill(count: 0), .automatic, .fixed(10, count: -2)).node

        XCTAssertEqual(node.props[GridContract.rows.token], ([.automatic] as [GridLength]).propValue)
    }
}
