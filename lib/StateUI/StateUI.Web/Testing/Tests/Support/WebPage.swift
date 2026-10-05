// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CWebTesting
@_spi(Host) import StateUI
@testable import StateUIWeb

/// What the page holds, as the suite reads it - an element's children, its style, its attributes, its words and a
/// field's value - and what the user does to it.
@MainActor
enum WebPage {
    /// The relay's numbers of the element's children, in their order on the page.
    static func children(of element: Int32) -> [Int32] {
        (0..<stateui_web_testing_child_count(element)).map { stateui_web_testing_child(element, $0) }
    }

    /// A CSS property of the element's own style; "" where it has none.
    static func style(of element: Int32, _ name: String) -> String {
        read(name) { stateui_web_testing_read_style(element, $0, $1) }
    }

    /// An attribute of the element; nil where it has none.
    static func attribute(of element: Int32, _ name: String) -> String? {
        let length = withUTF8(name) { stateui_web_testing_read_attribute(element, $0, $1) }
        return length < 0 ? nil : copyRead(length)
    }

    /// The element's words.
    static func text(of element: Int32) -> String {
        copyRead(stateui_web_testing_read_text(element))
    }

    /// A field's value.
    static func value(of element: Int32) -> String {
        copyRead(stateui_web_testing_read_value(element))
    }

    /// The user types `text` into the field, which then says so.
    static func enter(_ text: String, into element: Int32) {
        WebRelay.start()
        withUTF8(text) { stateui_web_testing_enter(element, $0, $1) }
    }

    /// The user leaves the field.
    static func leave(_ element: Int32) {
        WebRelay.start()
        stateui_web_testing_leave(element)
    }

    /// The user taps the element.
    static func tap(_ element: Int32) {
        WebRelay.start()
        stateui_web_testing_tap(element)
    }

    /// The user presses Escape on the modal dialog.
    static func dismiss(_ element: Int32) {
        WebRelay.start()
        stateui_web_testing_dismiss(element)
    }

    /// The application's own script tells `name` the words `words`.
    static func tell(_ name: String, _ words: String) {
        WebRelay.start()
        withUTF8(name) { name, length in withUTF8(words) { stateui_web_testing_tell(name, length, $0, $1) } }
    }

    /// The page lays the element out at `place` in its parent.
    static func layOut(_ element: Int32, at place: Rect) {
        stateui_web_testing_lay_out(element, place.x, place.y, place.width, place.height)
    }

    private static func read(_ name: String, _ reading: (UnsafePointer<CChar>?, Int32) -> Int32) -> String {
        copyRead(withUTF8(name, reading))
    }

    private static func copyRead(_ length: Int32) -> String {
        guard length > 0 else { return "" }
        let bytes = [UInt8](unsafeUninitializedCapacity: Int(length)) { buffer, count in
            buffer.withMemoryRebound(to: CChar.self) { stateui_web_testing_copy_read($0.baseAddress) }
            count = Int(length)
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func withUTF8<Result>(_ text: String, _ body: (UnsafePointer<CChar>?, Int32) -> Result) -> Result {
        var text = text
        return text.withUTF8 { bytes in bytes.withMemoryRebound(to: CChar.self) { body($0.baseAddress, Int32($0.count)) } }
    }
}
