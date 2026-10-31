// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
@_spi(Host) import StateUIFoundation
@testable import StateUIAndroid
import XCTest

/// libdispatch's main queue: a block an application sends it from another thread runs on the UI thread,
/// with nothing but the main looper turning.
final class AndroidMainQueueTests: XCTestCase {
    static var allTests: [(String, (AndroidMainQueueTests) -> () throws -> Void)] {
        [
            ("testABlockSentToTheMainQueueRunsOnTheUIThread", testABlockSentToTheMainQueueRunsOnTheUIThread),
        ]
    }

    func testABlockSentToTheMainQueueRunsOnTheUIThread() {
        onMainActor {
            AndroidMainQueue.watch()
            let ran = Ran()
            DispatchQueue.global().async {
                DispatchQueue.main.async { ran.thread = currentThreadNumber() }
            }

            for _ in 0..<200 {
                if ran.thread != nil { break }
                TestWindow.run(for: 10)
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
