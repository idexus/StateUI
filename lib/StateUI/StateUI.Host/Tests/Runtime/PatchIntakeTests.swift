// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How the core's messages come into the mounted tree: one whole message at a time, each claimed only when it
/// went in whole.
@MainActor
final class PatchIntakeTests: XCTestCase {
    /// A message applied while another applies is computed against a tree half written: the outer message claims
    /// no generation, so the next render is complete, and the message after it claims its own again.
    func testAMessageAppliedInsideAnotherClaimsNoGeneration() {
        let intake = PatchIntake()
        let root = HostPatch(id: .manual("root"), type: .vStack)
        intake.take(root, generation: 1) { _ in }
        XCTAssertEqual(intake.baseline, 1, "a message applied whole is claimed")

        intake.take(root, generation: 2) { _ in
            intake.take(root, generation: 3) { _ in }
        }
        XCTAssertEqual(intake.baseline, 0, "the next render is asked for whole")

        intake.take(root, generation: 4) { _ in }
        XCTAssertEqual(intake.baseline, 4)
    }
}
