// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
@_spi(Host) import StateUIFoundation
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

/// libdispatch's main queue: a block an application sends it from another thread runs on the UI thread,
/// with nothing but GLib's main loop turning.
final class GTKMainQueueTests: XCTestCase {
    func testABlockSentToTheMainQueueRunsOnTheUIThread() {
        onUIThread {
            GTKMainQueue.watch()
            let ran = Ran()
            DispatchQueue.global().async {
                DispatchQueue.main.async { ran.thread = currentThreadNumber() }
            }

            for _ in 0..<200 {
                if ran.thread != nil { break }
                GTKTestHost.pump(0.01)
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
