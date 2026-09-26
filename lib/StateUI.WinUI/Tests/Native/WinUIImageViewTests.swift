// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUIImageViewTests: XCTestCase {
    /// A picture read after its layouts were measured tells every layout above it, which grows around it.
    func testAPictureReadLateResizesTheLayoutsAboveIt() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack { HStack { Image("test_dot.png") } }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let row = try XCTUnwrap(host.views(WinUIStackView.self).last)
            host.settle { row.frame.width == 6 }

            XCTAssertTrue(row.frame == (0, 0, 6, 4), "\(row.frame)")
        }
    }
}
