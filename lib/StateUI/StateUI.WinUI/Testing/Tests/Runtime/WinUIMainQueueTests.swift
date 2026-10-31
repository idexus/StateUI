// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
@_spi(Host) import StateUIFoundation
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

/// libdispatch's main queue: a block an application sends it from another thread runs on the UI thread,
/// with nothing but the thread's messages running.
final class WinUIMainQueueTests: XCTestCase {
    func testABlockSentToTheMainQueueRunsOnTheUIThread() {
        onUIThread {
            WinUIMainQueue.watch()
            let ran = Ran()
            DispatchQueue.global().async {
                DispatchQueue.main.async { ran.thread = currentThreadNumber() }
            }

            for _ in 0..<200 {
                if ran.thread != nil { break }
                WinUITestHost.pump(0.01)
            }

            XCTAssertEqual(ran.thread, currentThreadNumber(), "the block runs on the UI thread")
        }
    }
}

/// The thread a block ran on.
@MainActor
private final class Ran {
    var thread: UInt64?
}
