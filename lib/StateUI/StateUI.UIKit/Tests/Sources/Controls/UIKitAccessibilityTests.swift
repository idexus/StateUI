// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// What VoiceOver meets of UIKit's views.
final class UIKitAccessibilityTests: XCTestCase {
    /// A control holding no children of the tree's - a date picker, a spinner - hidden from assistive technology
    /// hides the parts UIKit offers inside it too; a hidden layout keeps its children met.
    @MainActor
    func testAHiddenControlHidesItsOwnParts() throws {
        let host = UIKitRenderer.running {
            VStack {
                DatePicker(State(wrappedValue: CalendarDate(year: 2026, month: 9, day: 28)).projectedValue)
                    .isAccessibilityHidden(true)
                ActivityIndicator().isRunning(true).isAccessibilityHidden(true)
                VStack { Label("Met") }.isAccessibilityHidden(true)
            }
        }
        defer { host.finish() }
        let picker = try XCTUnwrap(host.views(UIKitDateTimePickerView.self).first)
        let spinner = try XCTUnwrap(host.views(UIKitActivityIndicatorView.self).first)
        XCTAssertTrue(picker.accessibilityElementsHidden, "the picker's parts")
        XCTAssertTrue(spinner.accessibilityElementsHidden, "the spinner's")
        let layout = try XCTUnwrap(host.views(UIKitStackView.self).last)
        XCTAssertFalse(layout.accessibilityElementsHidden, "a hidden layout keeps its children met")
    }
}
