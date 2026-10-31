// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@_spi(Host) import StateUIFoundation
import XCTest

/// The platform's main queue: a block an application sends it from another thread runs on the UI thread, with
/// nothing but UIKit's run loop turning it - as every host off Apple's turns libdispatch's.
@MainActor
final class UIKitMainQueueTests: XCTestCase {
    func testABlockSentToTheMainQueueRunsOnTheUIThread() {
        let ran = Ran()
        DispatchQueue.global().async {
            DispatchQueue.main.async { ran.thread = currentThreadNumber() }
        }

        for _ in 0..<200 {
            if ran.thread != nil { break }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        XCTAssertEqual(ran.thread, currentThreadNumber(), "the block runs on the UI thread")
    }
}

/// The thread a block ran on.
@MainActor
private final class Ran {
    var thread: UInt64?
}
