// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUIStackViewTests: XCTestCase {
    /// A vertical stack stands its children one under another, `spacing` apart, each as tall as WinUI measured it.
    func testAVerticalStackStandsItsChildrenOneUnderAnother() {
        onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Label("one")
                    Label("two")
                }
                .spacing(10)
            }
            let labels = host.views(WinUILabelView.self).map(\.laidOutFrame)

            XCTAssertEqual(labels.count, 2)
            XCTAssertEqual(labels[0].y, 0)
            XCTAssertGreaterThan(labels[0].height, 10, "WinUI measured no words")
            XCTAssertEqual(labels[1].y, labels[0].height + 10, accuracy: 0.5)
        }
    }

    /// A horizontal stack stands its children side by side; padding keeps them in from its edge.
    func testAHorizontalStackStandsItsChildrenSideBySideWithinItsPadding() {
        onUIThread {
            let host = WinUIRenderer.running {
                HStack {
                    Label("left")
                    Label("right")
                }
                .spacing(6)
                .padding(Insets(4))
            }
            let labels = host.views(WinUILabelView.self).map(\.laidOutFrame)

            XCTAssertEqual(labels.count, 2)
            XCTAssertEqual(labels[0].x, 4, accuracy: 0.5)
            XCTAssertEqual(labels[0].y, 4, accuracy: 0.5)
            XCTAssertEqual(labels[1].x, labels[0].x + labels[0].width + 6, accuracy: 0.5)
        }
    }
}
