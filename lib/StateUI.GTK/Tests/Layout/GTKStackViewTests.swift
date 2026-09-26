// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKStackViewTests: XCTestCase {
    /// A vertical stack stands its children one under another, `spacing` apart, each as tall as GTK measured it.
    func testAVerticalStackStandsItsChildrenOneUnderAnother() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Label("one")
                    Label("two")
                }
                .spacing(10)
            }
            let labels = host.views(GTKLabelView.self).map(\.laidOutFrame)

            XCTAssertEqual(labels.count, 2)
            XCTAssertEqual(labels[0].y, 0)
            XCTAssertGreaterThan(labels[0].height, 10, "GTK measured no words")
            XCTAssertEqual(labels[1].y, labels[0].height + 10, accuracy: 0.5)
        }
    }

    /// A horizontal stack stands its children side by side; padding keeps them in from its edge.
    func testAHorizontalStackStandsItsChildrenSideBySideWithinItsPadding() {
        onUIThread {
            let host = GTKRenderer.running {
                HStack {
                    Label("left")
                    Label("right")
                }
                .spacing(6)
                .padding(Insets(4))
            }
            let labels = host.views(GTKLabelView.self).map(\.laidOutFrame)

            XCTAssertEqual(labels.count, 2)
            XCTAssertEqual(labels[0].x, 4, accuracy: 0.5)
            XCTAssertEqual(labels[0].y, 4, accuracy: 0.5)
            XCTAssertEqual(labels[1].x, labels[0].x + labels[0].width + 6, accuracy: 0.5)
        }
    }

    /// A button's size is its whole CSS box, as GTK measures it: the next child stands below all of it.
    func testAButtonTakesItsWholeBox() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("Tap")
                    Label("below")
                }
            }
            let button = host.views(GTKButtonView.self)[0]
            let measured = button.measure(width: nil, height: nil)

            XCTAssertEqual(button.laidOutFrame.height, measured.height, accuracy: 0.5)
            XCTAssertEqual(host.views(GTKLabelView.self)[0].laidOutFrame.y, measured.height, accuracy: 0.5)
        }
    }
}
