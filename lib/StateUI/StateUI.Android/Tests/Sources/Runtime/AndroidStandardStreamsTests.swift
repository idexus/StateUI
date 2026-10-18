// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
@testable import StateUIAndroid
import XCTest

final class AndroidStandardStreamsTests: XCTestCase {
    static var allTests: [(String, (AndroidStandardStreamsTests) -> () throws -> Void)] {
        [
            ("testTheStreamsAreLedToLogcatOnceForTheProcess", testTheStreamsAreLedToLogcatOnceForTheProcess),
        ]
    }

    /// Stdout and stderr are led to logcat once for the process: an activity started after another opens no second
    /// pipe and starts no second reader.
    func testTheStreamsAreLedToLogcatOnceForTheProcess() {
        onMainActor {
            AndroidStandardStreams.redirect()
            let led = Self.pipe(of: 1)

            AndroidStandardStreams.redirect()

            XCTAssertEqual(Self.pipe(of: 1), led, "stdout's pipe")
            XCTAssertEqual(Self.pipe(of: 2), led, "stderr's")
        }
    }

    /// The node the descriptor `descriptor` stands for.
    private static func pipe(of descriptor: Int32) -> UInt64 {
        var facts = stat()
        fstat(descriptor, &facts)
        return UInt64(facts.st_ino)
    }
}
