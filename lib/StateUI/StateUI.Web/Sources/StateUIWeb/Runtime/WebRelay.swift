// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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

    /// Makes an element of SVG's - `svg`, `path` - and answers its number.
    static func createVector(_ tag: String) -> Int32 {
        utf8(tag) { stateui_web_create_vector($0, $1) }
    }

    /// An SVG shape's bounds in its own space, before any transform.
    static func shapeBounds(of element: Int32) -> Rect {
        let read = numbers(4) { stateui_web_read_shape_bounds(element, $0) }
        return Rect(x: read[0], y: read[1], width: read[2], height: read[3])
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

    static func setFlag(_ element: Int32, _ name: String, _ on: Bool) {
        utf8(name) { stateui_web_set_flag(element, $0, $1, on ? 1 : 0) }
    }

    static func flag(of element: Int32, _ name: String) -> Bool {
        utf8(name) { stateui_web_read_flag(element, $0, $1) != 0 }
    }

    static func setNumber(_ element: Int32, _ name: String, _ value: Double) {
        utf8(name) { stateui_web_set_number(element, $0, $1, value) }
    }

    static func number(of element: Int32, _ name: String) -> Double {
        utf8(name) { stateui_web_read_number(element, $0, $1) }
    }

    /// Selects `length` UTF-16 units of a field's words from `start`.
    static func select(_ element: Int32, from start: Int, length: Int) {
        stateui_web_select(element, Int32(start), Int32(length))
    }

    /// Steps a number field `by` steps within its range.
    static func step(_ element: Int32, by steps: Int32) {
        stateui_web_step(element, steps)
    }

    static func value(of element: Int32) -> String {
        copyRead(length: stateui_web_read_value(element))
    }

    static func listen(_ element: Int32, _ event: String, _ listener: Int32) {
        utf8(event) { stateui_web_listen(element, $0, $1, listener) }
    }

    /// How many clicks the event being heard counts.
    static var eventClicks: Int { Int(stateui_web_event_number(0)) }

    /// Where the pointer of the event being heard is, from the listening element's top left corner.
    static var eventPoint: Point { Point(x: stateui_web_event_number(1), y: stateui_web_event_number(2)) }

    static func observeSize(_ element: Int32, _ listener: Int32) {
        stateui_web_observe_size(element, listener)
    }

    /// The element's box on the page, from the page's top left.
    static func box(of element: Int32) -> Rect {
        let read = numbers(4) { stateui_web_read_box(element, $0) }
        return Rect(x: read[0], y: read[1], width: read[2], height: read[3])
    }

    /// The element's size in its layout, before any transform.
    static func size(of element: Int32) -> LayoutSize {
        let read = numbers(2) { stateui_web_read_size(element, $0) }
        return LayoutSize(width: read[0], height: read[1])
    }

    /// How far the element is scrolled.
    static func scroll(of element: Int32) -> Point {
        let read = numbers(2) { stateui_web_read_scroll(element, $0) }
        return Point(x: read[0], y: read[1])
    }

    static func scroll(_ element: Int32, to point: Point) {
        stateui_web_scroll_to(element, point.x, point.y)
    }

    /// `count` numbers the relay writes.
    private static func numbers(_ count: Int, _ read: (UnsafeMutablePointer<Double>) -> Void) -> [Double] {
        [Double](unsafeUninitializedCapacity: count) { buffer, written in
            read(buffer.baseAddress!)
            written = count
        }
    }

    static func setTitle(_ title: String) {
        utf8(title) { stateui_web_set_title($0, $1) }
    }

    static func requestFrame() {
        stateui_web_request_frame()
    }

    /// Asks the page to call once more after `milliseconds`, in place of the call asked for before.
    static func wake(after milliseconds: Double) {
        stateui_web_wake_after(milliseconds)
    }

    static var now: Double { stateui_web_now() }

    static var prefersDark: Bool { stateui_web_prefers_dark() != 0 }

    /// Whether the user asked for less motion.
    static var reducesMotion: Bool { stateui_web_reduces_motion() != 0 }

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
