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
        let sent = Sent()
        DispatchQueue.global().async {
            sent.mark()
            DispatchQueue.main.async { ran.thread = currentThreadNumber() }
        }

        for _ in 0..<200 {
            if ran.thread != nil { break }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        XCTAssertEqual(ran.thread, currentThreadNumber(), "the block runs on the UI thread - \(Self.stalled(sent: sent.marked))")
    }

    /// Which half of the way stalled, and what the test stands in: a run loop under a block of the main queue serves
    /// that queue no more.
    private static func stalled(sent: Bool) -> String {
        guard sent else { return "the global queue never ran its block" }
        let frames = Thread.callStackSymbols.compactMap { $0.split(separator: " ", omittingEmptySubsequences: true).dropFirst(3).first }
        let inside = frames.contains { $0.contains("_dispatch_main_queue") || $0.contains("MAIN_DISPATCH_QUEUE") }
        return "the main queue never ran the block sent to it, the test \(inside ? "inside" : "outside") a block of that queue: "
            + frames.joined(separator: " < ")
    }
}

/// The thread a block ran on.
@MainActor
private final class Ran {
    var thread: UInt64?
}

/// Whether the global queue's block ran, marked from its thread.
private final class Sent: @unchecked Sendable {
    private let lock = NSLock()
    private var sent = false

    func mark() { lock.withLock { sent = true } }
    var marked: Bool { lock.withLock { sent } }
}
