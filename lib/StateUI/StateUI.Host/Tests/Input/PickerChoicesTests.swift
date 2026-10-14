// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A picker is made as a menu unless the patch it is made from says segments or radio buttons.
@MainActor
final class PickerChoicesTests: XCTestCase {
    func testAPickerIsAMenuUnlessItSaysOtherwise() {
        var patch = HostPatch(id: .manual("p"), type: .picker)
        XCTAssertEqual(PickerChoices.presentation(made: patch), .menu, "nothing said")
        XCTAssertEqual(PickerChoices.presentation(made: nil), .menu, "no patch")

        patch.properties = [Prop.presentation: PickerPresentation.segmented.propValue]
        XCTAssertEqual(PickerChoices.presentation(made: patch), .segmented)
        patch.properties = [Prop.presentation: PickerPresentation.radio.propValue]
        XCTAssertEqual(PickerChoices.presentation(made: patch), .radio)
    }
}
