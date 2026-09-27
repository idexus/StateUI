// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import XCTest

/// WinUI's own ItemsView under the host: a list measured in the room it stands in.
final class WinUIItemsViewTests: XCTestCase {
    /// A list whose window is widened and narrowed stands at each new width: a layout WinUI cannot settle ends the
    /// process.
    func testAListWhoseWindowChangesItsWidthSettles() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                Grid {
                    ItemsView(0..<1_000) { number in
                        HStack {
                            Label("\(number)").width(90)
                            Label("\(number * number)")
                        }
                        .padding(14, 10)
                    }
                    .header(Label("N and N²").padding(14, 8))
                    .gridRow(0)

                    Label("Tap a row.").gridRow(1)
                }
                .rows(.fill, .auto)
            }
            let list = try XCTUnwrap(host.views(WinUIItemsView.self).first)
            let window = try XCTUnwrap(host.window)

            for (width, height) in [(750.0, 700.0), (1200.0, 750.0), (650.0, 600.0), (1300.0, 800.0)] {
                window.request(WindowFrame(width: width, height: height))
                host.settle(until: { abs(list.laidOutFrame.width - width) < 0.5 })
                XCTAssertEqual(list.laidOutFrame.width, width, accuracy: 0.5, "the list stands as wide as its window")
            }
        }
    }
}
