// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKKeysTests: XCTestCase {
    /// The keypad's Enter is the key Return is, as every platform's Enter is: a shortcut of Return takes it.
    func testTheKeypadsEnterIsReturn() {
        let none = GdkModifierType(rawValue: 0)
        XCTAssertEqual(GTKKeys.shortcut(keyval: guint(GDK_KEY_KP_Enter), modifiers: none), KeyboardShortcut(.return, modifiers: []))
        XCTAssertEqual(GTKKeys.shortcut(keyval: guint(GDK_KEY_Return), modifiers: none), KeyboardShortcut(.return, modifiers: []))
    }
}
