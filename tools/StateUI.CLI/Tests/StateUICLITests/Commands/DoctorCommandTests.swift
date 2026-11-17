// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import StateUIToolingProtocol
import XCTest

final class DoctorCommandTests: XCTestCase {
    /// `doctor` reports every component in its envelope, and ends with 0 where Swift is found.
    func testDoctorReportsEveryComponent() async throws {
        let (outcome, output, _) = try await Stateui.run("doctor", "--format", "json")
        let report = try ToolingJSON.decoder().decode(
            Envelope<ToolchainReport>.self, from: Data(output.joined(separator: "\n").utf8)).result

        XCTAssertEqual(report.findings.first?.component, "Swift 6.4 or newer")
        XCTAssertEqual(outcome.termination, report.lacks(for: nil) ? .exited(3) : .exited(0))
    }

    /// Without the Swift every host needs, `doctor` says so, how to get it, and ends with status 3.
    func testDoctorWithoutSwiftEndsWith3() async throws {
        let request = ProcessRequest(
            .path(Stateui.path), arguments: ["doctor", "--host", "web"],
            environment: ProcessEnvironment.inherited.setting("SWIFT_BIN", to: "/no/such/swift"), timeout: .seconds(120))
        let output = Gathered()
        let outcome = try await ProcessRunner().run(request, output: output.add)

        XCTAssertEqual(outcome.termination, .exited(3))
        XCTAssertTrue(output.lines(of: .standardOutput).first?.hasPrefix("✗ Swift 6.4 or newer - not found") == true)
    }

    /// A guest is checked for a host, and one that is not here is said missing - of the guest by its name, or for want
    /// of Parallels' prlctl - with status 3; a guest named without a host is refused.
    func testAGuestNotHereIsSaidMissing() async throws {
        let (outcome, output, _) = try await Stateui.run("doctor", "--host", "gtk", "--device", "No Such Guest", "--format", "json")
        let report = try ToolingJSON.decoder().decode(
            Envelope<ToolchainReport>.self, from: Data(output.joined(separator: "\n").utf8)).result
        let missing = try XCTUnwrap(report.findings.first { $0.found == nil })
        XCTAssertTrue(missing.machine == "No Such Guest" || missing.component == "Parallels Desktop's prlctl", "\(missing)")
        XCTAssertEqual(outcome.termination, .exited(3))

        let (unnamed, _, _) = try await Stateui.run("doctor", "--device", "No Such Guest")
        XCTAssertEqual(unnamed.termination, .exited(2))
    }
}
