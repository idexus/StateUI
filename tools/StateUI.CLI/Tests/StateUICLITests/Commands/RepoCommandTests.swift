// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class RepoCommandTests: XCTestCase {
    /// A suite's own options are refused with a plan before anything runs - none of them quietly dropped.
    func testASuitesOptionsAreRefusedWithAPlan() async throws {
        for options in [["--filter", "ServeCommandTests"], ["--build-only"], ["--architecture", "arm64"], ["--artifact", "/tmp/apk"]] {
            let (outcome, _, errors) = try await Stateui.run(["repo", "test", "--plan", "portable", "--suite", "nothing"] + options)
            XCTAssertFalse(outcome.succeeded, "\(options)")
            XCTAssertTrue(errors.joined().contains("--suite alone"), "\(options): \(errors)")
        }
    }
}
