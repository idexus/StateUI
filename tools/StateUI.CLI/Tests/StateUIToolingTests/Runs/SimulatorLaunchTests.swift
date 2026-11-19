// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class SimulatorLaunchTests: XCTestCase {
    /// A launch simctl refuses is told by simctl's own words and how it ended, as every step's refusal is.
    func testALaunchRefusedSaysWhatSimctlSaid() async throws {
        #if os(macOS)
        let logs = FileManager.default.temporaryDirectory.appendingPathComponent("launch-\(UUID().uuidString)")
        let launch = SimulatorLaunch(
            simulator: Destination(id: "none", udid: "no-such-device", name: "None", kind: .simulator, version: "27.0"),
            bundle: logs.appendingPathComponent("None.app"), identifier: "com.example.none", logs: logs,
            environment: HandedEnvironment(of: [:]))
        do {
            _ = try await launch.launch(held: false, out: logs.appendingPathComponent("out"), err: logs.appendingPathComponent("err"))
            XCTFail("a launch on no simulator started")
        } catch let error as ToolingError {
            XCTAssertTrue(error.message.contains("xcrun simctl launch refused - it exited with status"), error.message)
            XCTAssertTrue(error.message.contains("Invalid device: no-such-device"), error.message)
        }
        #else
        throw XCTSkip("simctl is a Mac's")
        #endif
    }
}
