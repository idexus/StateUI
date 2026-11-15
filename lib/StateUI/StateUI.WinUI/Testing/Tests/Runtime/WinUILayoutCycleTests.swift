// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import Synchronization
import XCTest

/// What the library said while a test ran.
private let said = Mutex<[String]>([])

final class WinUILayoutCycleTests: XCTestCase {
    /// A window whose layout never settles is complained of, and the application goes on: WinUI gives up on it with
    /// a layout cycle, which would end the process.
    /// Design: docs/design/platforms/winui/layout.md#a-layout-that-does-not-settle
    func testALayoutThatNeverSettlesIsComplainedOf() throws {
        try onUIThread {
            Complaints.route { words in said.withLock { $0.append(words) } }
            defer { Complaints.route(to: nil) }
            let host = WinUIRenderer.running { VStack { Text("Settled") } }
            host.layOut()

            let stack = try XCTUnwrap(host.views(WinUIStackView.self).first)
            stateui_winui_unsettle(stack.handle)
            let complaint = LayoutComplaint.didNotSettle(on: "Windows")
            host.settle { said.withLock { $0.contains(complaint) } }
            XCTAssertTrue(said.withLock { $0.contains(complaint) }, "complained of")

            host.layOut()
            XCTAssertEqual(host.views(WinUITextView.self).first?.text, "Settled", "the application goes on")
        }
    }
}
