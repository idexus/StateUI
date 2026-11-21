// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@testable import StateUIUIKit
import XCTest

/// A field's return key on iOS, whose keyboard is on the screen.
/// Design: docs/design/types/keyboard.md#the-keyboard-down
@MainActor
final class UIKitFieldReturnTests: XCTestCase {
    /// A RETURN THAT ENDS THE TYPING TAKES THE KEYBOARD DOWN: a field submitted by the platform's own return, by
    /// Done, by Go - and a search field by its Search - gives the keyboard up; one whose return says Send keeps it
    /// for the next message.
    func testAReturnThatEndsTheTypingTakesTheKeyboardDown() throws {
        let host = UIKitRenderer.running {
            VStack {
                TextField("")
                TextField("").submitLabel(.done)
                TextField("").submitLabel(.go)
                TextField("").submitLabel(.send)
                SearchField("")
            }
        }
        defer { host.finish() }
        let fields: [UITextField] = host.views(UIKitTextFieldView.self) + host.views(UIKitSearchFieldView.self)
        XCTAssertEqual(fields.count, 5)

        let keeps = fields.map { field in
            XCTAssertTrue(field.becomeFirstResponder(), "the field takes the keyboard")
            _ = field.delegate?.textFieldShouldReturn?(field)
            return field.isFirstResponder
        }
        XCTAssertEqual(keeps, [false, false, false, true, false], "Send alone keeps the keyboard")
    }
}
