// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class ToolStepTests: XCTestCase {
    /// A step that failed is told by how it ended: its status, the signal, the limit it ran past, or its cancellation.
    func testAFailedStepSaysHowItEnded() {
        XCTAssertEqual(ToolStep.ending(ProcessOutcome(termination: .exited(3)), limit: .seconds(5)), "it exited with status 3")
        XCTAssertEqual(ToolStep.ending(ProcessOutcome(termination: .signaled(9)), limit: .seconds(5)), "signal 9 ended it")
        XCTAssertEqual(
            ToolStep.ending(ProcessOutcome(termination: .signaled(9), stop: .timeout), limit: .seconds(300)),
            "it ran past \(Duration.seconds(300))")
        XCTAssertEqual(
            ToolStep.ending(ProcessOutcome(termination: .signaled(15), stop: .cancellation), limit: .seconds(5)),
            "it was cancelled")
    }

    /// A step that fails saying nothing still says how it ended.
    func testAStepFailingInSilenceSaysHowItEnded() async throws {
        #if os(Windows)
        throw XCTSkip("the silent program is a shell's")
        #else
        do {
            try await ToolStep.run(.path("/bin/sh"), ["-c", "exit 3"])
            XCTFail("a failing step passed")
        } catch let error as ToolingError {
            XCTAssertEqual(error.code, .toolFailed)
            XCTAssertTrue(error.message.hasPrefix("sh -c refused - it exited with status 3"), error.message)
        }
        #endif
    }
}
