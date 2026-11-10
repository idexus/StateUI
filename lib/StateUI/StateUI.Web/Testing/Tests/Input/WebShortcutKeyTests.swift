// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// The character a shortcut's key writes is the one the user's layout puts on it - a German keyboard's Z is its Y -
/// and the key's own place where the layout writes no Latin letter or digit there: a Russian layout's, a French
/// digit row's, a key turned by Alt.
final class WebShortcutKeyTests: XCTestCase {
    func testAShortcutsKeyIsTheLayoutsLetterElseItsPlace() {
        let cases: [(written: String, physical: String, read: Character?, layout: String)] = [
            ("z", "z", "z", "US"),
            ("Z", "z", "z", "US, Shift held"),
            ("y", "z", "y", "German: the key in Z's place writes Y"),
            ("z", "y", "z", "German: the key in Y's place writes Z"),
            ("a", "q", "a", "French: the key in Q's place writes A"),
            ("&", "1", "1", "French: the digit row writes & unshifted"),
            ("я", "z", "z", "Russian: a Cyrillic letter stands on Z's key"),
            ("Ω", "z", "z", "macOS, Alt held: Z writes Ω"),
            ("/", "", "/", "a key that is no letter's place"),
            ("", "", nil, "no character"),
        ]
        for each in cases {
            XCTAssertEqual(
                WebKeys.character(written: each.written.unicodeScalars.first?.value ?? 0,
                                  physical: each.physical.unicodeScalars.first?.value ?? 0),
                each.read, each.layout)
        }
    }

    /// A shortcut is spelled as `aria-keyshortcuts` names its keys - a letter by its capital, the plus by its name,
    /// a key writing nothing by the page's name - and read back as the same shortcut.
    func testAShortcutIsSpelledAsAssistiveTechnologyNamesIt() {
        let cases: [(shortcut: KeyboardShortcut, spelled: String)] = [
            (KeyboardShortcut("s", modifiers: [.primary, .shift]), "Control+Shift+S"),
            (KeyboardShortcut("+", modifiers: .primary), "Control+Plus"),
            (KeyboardShortcut(.space, modifiers: .alt), "Alt+Space"),
            (KeyboardShortcut(Key(.return), modifiers: .primary), "Control+Enter"),
        ]
        for each in cases {
            XCTAssertEqual(WebKeys.spelled(each.shortcut, onApple: false), each.spelled)
            XCTAssertEqual(WebKeys.shortcut(spelled: each.spelled, onApple: false), each.shortcut, each.spelled)
        }
    }
}
