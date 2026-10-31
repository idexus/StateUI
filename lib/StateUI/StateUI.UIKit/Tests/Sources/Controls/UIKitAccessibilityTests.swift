// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// What VoiceOver meets of UIKit's views.
@MainActor
final class UIKitAccessibilityTests: XCTestCase {
    /// A control holding no children of the tree's - a date picker, a spinner - hidden from assistive technology
    /// hides the parts UIKit offers inside it too; a hidden layout keeps its children met.
    @MainActor
    func testAHiddenControlHidesItsOwnParts() throws {
        let host = UIKitRenderer.running {
            VStack {
                DatePicker(State(wrappedValue: CalendarDate(year: 2026, month: 9, day: 28)).projectedValue)
                    .isAccessibilityHidden(true)
                Spinner().isAnimating(true).isAccessibilityHidden(true)
                VStack { Text("Met") }.isAccessibilityHidden(true)
            }
        }
        defer { host.finish() }
        let picker = try XCTUnwrap(host.views(UIKitDatePickerView.self).first)
        let spinner = try XCTUnwrap(host.views(UIKitSpinnerView.self).first)
        XCTAssertTrue(picker.accessibilityElementsHidden, "the picker's parts")
        XCTAssertTrue(spinner.accessibilityElementsHidden, "the spinner's")
        let layout = try XCTUnwrap(host.views(UIKitStackView.self).last)
        XCTAssertFalse(layout.accessibilityElementsHidden, "a hidden layout keeps its children met")
    }

    /// A stack given a label - or answering a tap - is one thing to VoiceOver, its label standing for all it holds,
    /// as on every host; a plain one is UIKit's own, its children met.
    @MainActor
    func testAStackWithWordsOfItsOwnIsOneThing() throws {
        let host = UIKitRenderer.running {
            VStack {
                VStack { Text("A"); Text("B") }.accessibilityLabel("Card")
                VStack { Text("C") }.onTapped {}
                VStack { Text("D") }
            }
        }
        defer { host.finish() }
        let stacks = host.views(UIKitStackView.self).dropFirst()

        XCTAssertEqual(stacks.map(\.isAccessibilityElement), [true, true, false])
    }

    /// A view whose presence the tree stops saying stands as UIKit has it again.
    @MainActor
    func testAViewTheTreeStopsSayingOfStandsAsItsOwn() {
        let view = UIView()
        let own = view.isAccessibilityElement
        view.accessibility(
            AccessibilityWords(identifier: nil, label: nil, hint: nil, headingLevel: 0, presence: .met),
            holdingNoChildren: false, standing: own)
        XCTAssertTrue(view.isAccessibilityElement)

        view.accessibility(
            AccessibilityWords(identifier: nil, label: nil, hint: nil, headingLevel: 0, presence: nil),
            holdingNoChildren: false, standing: own)
        XCTAssertEqual(view.isAccessibilityElement, own)
    }
}
