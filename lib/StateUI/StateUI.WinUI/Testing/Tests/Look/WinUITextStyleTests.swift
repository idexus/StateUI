// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUITextStyleTests: XCTestCase {
    /// Each style stands at its step of WinUI's type ramp - the largest at TitleLarge, the largest title WinUI's own
    /// pages head with, in proportion to the other platforms' largest.
    func testEachStyleStandsAtItsStepOfTheRamp() {
        onUIThread {
            let styles: [TextStyle] = [.display, .title, .subtitle, .headline, .body, .caption]
            let host = WinUIRenderer.running {
                VStack { ForEach(Array(styles.enumerated()), id: \.offset) { Text("Words").textStyle($0.element) } }
            }
            let words = host.views(WinUITextView.self)
            host.settle { words.count == styles.count }

            XCTAssertEqual(words.map(\.wordsStyle.size), [40, 28, 20, 14, 14, 12])
            XCTAssertEqual(words.map(\.wordsStyle.weight), [600, 600, 600, 600, 400, 400])
        }
    }
}
