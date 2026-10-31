// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import XCTest
@testable import StateUIAppKit

/// AppKit's color well answers VoiceOver with its own action alone, whatever is set on it: the picker offers the
/// actions the tree gives beside the well's own.
@MainActor
final class AppKitColorPickerViewTests: XCTestCase {
    func testTheTreesActionsStandBesideTheWellsOwn() {
        let picker = AppKitColorPickerView()
        let own = picker.accessibilityCustomActions()?.map(\.name) ?? []

        picker.setAccessibilityCustomActions([NSAccessibilityCustomAction(name: "Delete") { true }])
        XCTAssertEqual(picker.accessibilityCustomActions()?.map(\.name), ["Delete"] + own)

        picker.setAccessibilityCustomActions(nil)
        XCTAssertEqual(picker.accessibilityCustomActions()?.map(\.name) ?? [], own, "the well's own once the tree's go")
    }
}
#endif
