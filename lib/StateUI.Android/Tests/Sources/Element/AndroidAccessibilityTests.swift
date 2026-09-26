// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
import XCTest

final class AndroidAccessibilityTests: XCTestCase {
    static var allTests: [(String, (AndroidAccessibilityTests) -> () throws -> Void)] {
        [
            ("testAViewSaysWhatAssistiveTechnologyMeets", testAViewSaysWhatAssistiveTechnologyMeets),
            ("testWordsTakenAwayLeaveTheViewsOwn", testWordsTakenAwayLeaveTheViewsOwn),
        ]
    }

    /// The name a test finds a view by, the words read for it and its hint, a heading, and whether it - or it
    /// and everything in it - is met; a view that says nothing is as it is of itself: a text is met, a layout
    /// as Android decides.
    func testAViewSaysWhatAssistiveTechnologyMeets() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Label("Save")
                        .accessibilityIdentifier("save")
                        .accessibilityLabel("Save the file")
                        .accessibilityHint("Writes it to disk")
                        .accessibilityHeadingLevel(.level2)
                    Label("Hidden").isAccessibilityHidden(true)
                    Label("Met").isAccessibilityHidden(false)
                    VStack { Label("Inside") }.automationExcludedWithChildren(true)
                    Label("Plain")
                }
            }

            XCTAssertEqual(host.views(AndroidLabelView.self).map(TestAccessibility.describe), [
                "id save, label Save the file, hint Writes it to disk, heading, met", "hidden", "met", "met", "met",
            ])
            XCTAssertEqual(host.views(AndroidStackView.self).map(TestAccessibility.describe), ["", "hidden with children"])
        }
    }

    /// Words taken away leave the view's own: its words read, no hint, no name, met as a text is.
    func testWordsTakenAwayLeaveTheViewsOwn() {
        onMainActor {
            let said = State(wrappedValue: true)
            let host = AndroidRenderer.running {
                if !said.wrappedValue { return Label("Save") }
                return Label("Save")
                    .accessibilityIdentifier("save")
                    .accessibilityLabel("Save the file")
                    .accessibilityHint("Writes it to disk")
                    .isAccessibilityHidden(true)
            }

            said.wrappedValue = false
            host.pump()

            XCTAssertEqual(host.views(AndroidLabelView.self).map(TestAccessibility.describe), ["met"])
        }
    }
}

/// What assistive technology meets of a view, as words: `TestAccessibility.java`.
@MainActor
enum TestAccessibility {
    private static let owner = Java.findClass("stateui/android/test/TestAccessibility")
    private static let describing = Java.staticMethod(owner, "describe", "(Landroid/view/View;)Ljava/lang/String;")

    static func describe(_ view: AndroidView) -> String {
        Java.frame { Java.callStaticObject(owner, describing, .object(view.reference)).map { Java.text($0) } ?? "" }
    }
}
