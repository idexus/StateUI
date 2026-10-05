// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWeb

/// The JavaScript relay beneath the host, in Swift's words: an element is the number the relay keeps it under,
/// words cross as UTF-8, and the page calls a listener back by its number.
/// Design: docs/design/platforms/web/runtime.md#the-relay
@MainActor
enum WebRelay {
    /// What each listener runs, by its number.
    private static var listeners: [Int32: () -> Void] = [:]
    private static var nextListener: Int32 = 1

    /// What a display frame runs, at its time.
    static var onFrame: ((Double) -> Void)?

    /// What runs once every call from the page has run its listener: the turn the browser's event loop asks for.
    static var afterEntry: () -> Void = {}

    /// Hands the page the two functions it calls Swift through.
    static func start() {
        handOver()
    }

    /// Hands them over from a nonisolated function: a closure written in a `@MainActor` one is MainActor's.
    private nonisolated static func handOver() {
        stateui_web_start(
            { listener in MainActor.assumeIsolated { WebRelay.heard(listener) } },
            { time in MainActor.assumeIsolated { WebRelay.frame(at: time) } })
    }

    private static func heard(_ listener: Int32) {
        listeners[listener]?()
        afterEntry()
    }

    private static func frame(at time: Double) {
        onFrame?(time)
        afterEntry()
    }

    /// A listener for `action`, under a number the page calls it by until `forget`.
    static func listener(_ action: @escaping () -> Void) -> Int32 {
        let number = nextListener
        nextListener += 1
        listeners[number] = action
        return number
    }

    /// Lets go of the listener `number`.
    static func forget(_ number: Int32) {
        listeners[number] = nil
    }

    static var body: Int32 { stateui_web_body() }

    static func create(_ tag: String) -> Int32 {
        utf8(tag) { stateui_web_create($0, $1) }
    }

    static func release(_ element: Int32) {
        stateui_web_release(element)
    }

    static func insert(_ child: Int32, into parent: Int32, at index: Int) {
        stateui_web_insert(parent, child, Int32(index))
    }

    static func detach(_ element: Int32) {
        stateui_web_detach(element)
    }

    static func setText(_ element: Int32, _ text: String) {
        utf8(text) { stateui_web_set_text(element, $0, $1) }
    }

    /// Sets an attribute, or takes it away for nil.
    static func setAttribute(_ element: Int32, _ name: String, _ value: String?) {
        utf8(name) { name, nameLength in
            guard let value else { return stateui_web_remove_attribute(element, name, nameLength) }
            utf8(value) { stateui_web_set_attribute(element, name, nameLength, $0, $1) }
        }
    }

    /// Sets a CSS property of the element's own style, or takes it away for nil.
    static func setStyle(_ element: Int32, _ name: String, _ value: String?) {
        utf8(name) { name, nameLength in
            utf8(value ?? "") { stateui_web_set_style(element, name, nameLength, $0, $1) }
        }
    }

    static func setValue(_ element: Int32, _ text: String) {
        utf8(text) { stateui_web_set_value(element, $0, $1) }
    }

    static func value(of element: Int32) -> String {
        copyRead(length: stateui_web_read_value(element))
    }

    static func listen(_ element: Int32, _ event: String, _ listener: Int32) {
        utf8(event) { stateui_web_listen(element, $0, $1, listener) }
    }

    static func setTitle(_ title: String) {
        utf8(title) { stateui_web_set_title($0, $1) }
    }

    static func requestFrame() {
        stateui_web_request_frame()
    }

    static var now: Double { stateui_web_now() }

    static var prefersDark: Bool { stateui_web_prefers_dark() != 0 }

    static func listenToAppearance(_ listener: Int32) {
        stateui_web_listen_appearance(listener)
    }

    /// The words the relay read last, `length` bytes of UTF-8.
    private static func copyRead(length: Int32) -> String {
        guard length > 0 else { return "" }
        let bytes = [UInt8](unsafeUninitializedCapacity: Int(length)) { buffer, count in
            buffer.withMemoryRebound(to: CChar.self) { stateui_web_copy_read($0.baseAddress) }
            count = Int(length)
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// `text` as the relay reads words: its UTF-8 and their length.
    private static func utf8<Result>(_ text: String, _ body: (UnsafePointer<CChar>?, Int32) -> Result) -> Result {
        var text = text
        return text.withUTF8 { bytes in
            bytes.withMemoryRebound(to: CChar.self) { body($0.baseAddress, Int32($0.count)) }
        }
    }
}
