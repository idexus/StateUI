// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A split button whose enablement a test turns.
private struct SplitPage: View {
    let enabled: State<Bool>

    var body: some View {
        Button("Save").onClicked {}.menu(.split) { MenuItem("Save as").onClicked {} }.isEnabled(enabled.projectedValue)
    }
}

/// A split button's arrow, as UIKit's own hit test finds it.
@MainActor
final class UIKitSplitArrowTests: XCTestCase {
    /// A disabled split button's arrow opens no menu: a touch on it reaches no control - UIKit's own hit test - and
    /// a screen reader hears it dimmed with its button; enabled again, it is a button opening the menu.
    func testADisabledSplitButtonsArrowOpensNoMenu() throws {
        let enabled = State(wrappedValue: false)
        let host = UIKitRenderer.running(reducesMotion: false) { SplitPage(enabled: enabled) }
        defer { host.finish() }
        let button = try XCTUnwrap(host.views(UIKitButtonView.self).first)
        host.layOut()
        let arrow = try XCTUnwrap(button.subviews.lazy.compactMap { $0 as? UIButton }.first { $0.menu != nil })
        func touched() -> UIControl? {
            button.hitTest(CGPoint(x: button.bounds.maxX - 8, y: button.bounds.midY), with: nil) as? UIControl
        }

        XCTAssertNil(touched(), "disabled, a touch reaches nothing")
        XCTAssertTrue(arrow.accessibilityTraits.contains(.notEnabled), "and a screen reader hears its arrow dimmed")
        enabled.wrappedValue = true
        host.settle { touched() === arrow }
        XCTAssertTrue(touched() === arrow, "enabled, a touch reaches its arrow")
        XCTAssertFalse(arrow.accessibilityTraits.contains(.notEnabled))
    }
}
