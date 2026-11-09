// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

/// Words `depth` grids deep, each grid with words and a stack of its own beside them.
@MainActor
private func nest(_ depth: Int, _ words: String) -> AnyView {
    guard depth > 0 else { return AnyView(Text(words).margin(2)) }

    return AnyView(Grid {
        nest(depth - 1, words)
        Text("beside \(depth)").gridRow(1)
        VStack {
            Text("a \(depth)")
            Text("b \(depth)")
        }
        .gridColumn(1)
    }
    .rows(.automatic, .automatic)
    .columns(.automatic, .fill)
    .margin(2))
}

final class WinUIMeasurementTests: XCTestCase {
    /// A change sizes only the layouts above it, each once for each width it is asked about: words changing six
    /// grids deep leave every layout beside them as it was sized - a layout measured at every width asked of it
    /// sized its whole subtree again each time.
    func testAChangeSizesOnlyTheLayoutsAboveIt() {
        onUIThread {
            let words = State(wrappedValue: "short")
            let host = WinUIRenderer.running { nest(6, words.wrappedValue) }
            host.layOut()

            let before = WinUILayoutView.sizings
            words.wrappedValue = "words a good deal longer"
            host.settle { host.views(WinUITextView.self).contains { $0.text == "words a good deal longer" } }
            host.layOut()

            XCTAssertLessThanOrEqual(WinUILayoutView.sizings - before, 60, "a few for each grid above it, none beside")
        }
    }

    /// A label that never wraps keeps its natural width whatever room is offered. WinUI measures such a line at
    /// the width just under its own - an ellipsis's worth shorter - so a layout feeding that size back into the
    /// room it offers measures it again for ever.
    /// Design: docs/design/platforms/winui/layout.md#measured-every-pass
    func testALabelThatNeverWrapsKeepsItsNaturalWidth() {
        onUIThread {
            let label = WinUITextualView()
            label.setText("words that never wrap")
            label.setLines(breaking: .noWrap, maximum: nil)

            let natural = label.measure(width: nil, height: nil)
            let narrower = label.measure(width: natural.width - 1, height: nil)

            XCTAssertEqual(narrower.width, natural.width, "a line that never wraps keeps its size")
        }
    }

    /// A button's caption that never wraps keeps its natural width too, so a layout cannot measure it for ever at
    /// the width it feeds back.
    /// Design: docs/design/platforms/winui/layout.md#measured-every-pass
    func testAButtonsNonWrappingCaptionKeepsItsNaturalWidth() {
        onUIThread {
            let button = WinUIButtonView()
            button.setText("words that never wrap")

            let natural = button.measure(width: nil, height: nil)
            let narrower = button.measure(width: natural.width - 1, height: nil)

            XCTAssertEqual(narrower.width, natural.width, "a button's line that never wraps keeps its size")
        }
    }
}
