// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKIndicatorViewTests: XCTestCase {
    /// A bar fills in its tint as far as its work went, and no further.
    func testABarFillsInItsTintAsFarAsItsWorkWent() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    ProgressBar(0.5).tint(Color("#FF0000")).width(200).height(8)
                    ProgressBar(1.5).width(200).height(8)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let bars = host.views(GTKProgressBarView.self)
            host.settle { bars[0].pixels(at: [(20, 4)]) == [0xFFFF_0000] }

            XCTAssertEqual(bars[0].pixels(at: [(20, 4), (180, 4)]).map { $0 == 0xFFFF_0000 }, [true, false])
        }
    }
}
