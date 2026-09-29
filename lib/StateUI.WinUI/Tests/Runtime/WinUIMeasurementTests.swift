// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import XCTest

/// Words `depth` grids deep, each grid with words and a stack of its own beside them.
private func nest(_ depth: Int, _ words: String) -> Node {
    guard depth > 0 else { return Label(words).margin(2).body }

    return Grid {
        nest(depth - 1, words)
        Label("beside \(depth)").gridRow(1)
        VStack {
            Label("a \(depth)")
            Label("b \(depth)")
        }
        .gridColumn(1)
    }
    .rows(.auto, .auto)
    .columns(.auto, .fill)
    .margin(2)
    .body
}

final class WinUIMeasurementTests: XCTestCase {
    /// A change sizes only the layouts above it, each once for each width it is asked about: words changing six
    /// grids deep leave every layout beside them as it was sized - a layout measured at every width asked of it
    /// sized its whole subtree again each time.
    func testAChangeSizesOnlyTheLayoutsAboveIt() {
        onUIThread {
            let words = State(wrappedValue: "short")
            let host = WinUIRenderer.running { ModifiedContent(node: nest(6, words.wrappedValue)) }
            host.layOut()

            let before = WinUILayoutView.sizings
            words.wrappedValue = "words a good deal longer"
            host.settle { host.views(WinUILabelView.self).contains { $0.text == "words a good deal longer" } }
            host.layOut()

            XCTAssertLessThanOrEqual(WinUILayoutView.sizings - before, 60, "a few for each grid above it, none beside")
        }
    }
}
