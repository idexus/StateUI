// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidRegistrationTests: XCTestCase {
    static var allTests: [(String, (AndroidRegistrationTests) -> () throws -> Void)] {
        [
            ("testTheRegistryRealizesTheFirstSlice", testTheRegistryRealizesTheFirstSlice),
        ]
    }

    /// What the host presents is what its registry says it realizes, member by member.
    func testTheRegistryRealizesTheFirstSlice() {
        onMainActor {
            let realization = AndroidRegistrations.registry.realization

            XCTAssertEqual(realization.elements, ["Button", "HStack", "Label", "VStack"])
            XCTAssertTrue(realization.members.contains(
                HostRealizedMember(element: "Button", owner: "Button", member: "clicked")))
            XCTAssertTrue(realization.members.contains(
                HostRealizedMember(element: "Label", owner: "TextElement", member: "text")))
        }
    }
}
