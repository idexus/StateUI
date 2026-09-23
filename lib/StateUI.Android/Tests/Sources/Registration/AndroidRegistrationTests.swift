// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidRegistrationTests: XCTestCase {
    static var allTests: [(String, (AndroidRegistrationTests) -> () throws -> Void)] {
        [
            ("testTheRegistryRealizesWhatTheHostPresents", testTheRegistryRealizesWhatTheHostPresents),
        ]
    }

    /// What the host presents is what its registry says it realizes, member by member.
    func testTheRegistryRealizesWhatTheHostPresents() {
        onMainActor {
            let realization = AndroidRegistrations.registry.realization

            XCTAssertEqual(
                realization.elements,
                [
                    "AbsoluteLayout", "Border", "Button", "ColorBox", "Grid", "HStack", "Image", "Label", "ScrollView", "Slider",
                    "Switch", "TextField", "VStack",
                ])
            for member in [
                HostRealizedMember(element: "Button", owner: "Button", member: "clicked"),
                HostRealizedMember(element: "Label", owner: "TextElement", member: "text"),
                HostRealizedMember(element: "Switch", owner: "Switch", member: "toggled"),
                HostRealizedMember(element: "Slider", owner: "Slider", member: "valueChanged"),
                HostRealizedMember(element: "Slider", owner: "Slider", member: "dragCompleted"),
                HostRealizedMember(element: "TextField", owner: "InputView", member: "textChanged"),
                HostRealizedMember(element: "TextField", owner: "TextField", member: "submitted"),
                HostRealizedMember(element: "Grid", owner: "Grid", member: "rows"),
                HostRealizedMember(element: "Label", owner: "View", member: "gridRow"),
                HostRealizedMember(element: "Label", owner: "View", member: "absoluteLayoutBounds"),
                HostRealizedMember(element: "Border", owner: "Border", member: "shape"),
                HostRealizedMember(element: "Image", owner: "Image", member: "source"),
                HostRealizedMember(element: "ColorBox", owner: "ColorBox", member: "cornerRadius"),
            ] {
                XCTAssertTrue(realization.members.contains(member), "\(member)")
            }
        }
    }
}
