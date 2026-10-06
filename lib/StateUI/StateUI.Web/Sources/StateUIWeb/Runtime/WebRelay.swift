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

    /// A listener for `action`, let go of as the page calls it.
    static func once(_ action: @escaping () -> Void) -> Int32 {
        let number = nextListener
        nextListener += 1
        listeners[number] = { [number] in
            listeners[number] = nil
            action()
        }
        return number
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

    /// The pointer of the event being heard: its number, where it is on the page, its kind - 0 a mouse, 1 a pen, 2 a
    /// touch - and its button.
    static var eventPointer: (id: Int, at: Point, kind: Int, button: Int) {
        (Int(stateui_web_event_number(3)), Point(x: stateui_web_event_number(4), y: stateui_web_event_number(5)),
         Int(stateui_web_event_number(6)), Int(stateui_web_event_number(7)))
    }

    /// The wheel's turn down of the event being heard, and whether a key made it a pinch.
    static var eventWheel: (down: Double, pinches: Bool) {
        (stateui_web_event_number(8), stateui_web_event_number(9) != 0)
    }

    /// The scale of the gesture being heard, from 1 as it began.
    static var eventScale: Double { stateui_web_event_number(10) }

    /// The size of the element hearing the event.
    static var eventSize: LayoutSize {
        LayoutSize(width: stateui_web_event_number(11), height: stateui_web_event_number(12))
    }

    /// Whether the click being heard fell on a label beside its control, which the browser clicks next.
    static var eventPassesToControl: Bool { stateui_web_event_number(13) != 0 }

    /// Calls `listener` as `element` comes near the view of the scroller `root`, and as it goes away (`eventNear`).
    static func watchNearness(_ element: Int32, of root: Int32, _ listener: Int32) {
        stateui_web_watch_nearness(element, root, listener)
    }

    /// Whether the element the nearness being heard is of came near.
    static var eventNear: Bool { stateui_web_event_number(0) != 0 }

    /// Puts one entry of the page's own on the browser's history.
    static func pushHistory() {
        stateui_web_push_history()
    }

    /// Goes back over the page's own entry of the browser's history, where it stands on it - never off the site from
    /// an entry the page did not put there; whether it went.
    @discardableResult
    static func backHistory() -> Bool {
        stateui_web_back_history() != 0
    }

    /// What the page stands as: whether its tab shows, and whether it holds the keyboard.
    static var pageState: (shown: Bool, focused: Bool) {
        let state = stateui_web_page_state()
        return (state & 1 != 0, state & 2 != 0)
    }

    /// Calls `changed` as the page's tab shows or hides or the page takes or loses the keyboard, and `leaving` as
    /// the browser leaves the page.
    static func listenToPage(changed: Int32, leaving: Int32) {
        stateui_web_listen_page(changed, leaving)
    }

    /// Calls `listener` whenever the browser's history moves.
    static func listenToHistory(_ listener: Int32) {
        stateui_web_listen_history(listener)
    }

    /// Calls the act `name` of the application's scripts with `words`; `listener` hears its promise settle.
    static func callScript(_ name: String, _ words: String, _ listener: Int32) {
        utf8(name) { name, length in utf8(words) { stateui_web_call_script(name, length, $0, $1, listener) } }
    }

    /// What the scripts' act gave, or why it broke, or what they told.
    static var scriptWords: String { copyRead(length: stateui_web_script_words()) }

    /// Whether the scripts' act being heard kept its promise.
    static var scriptKept: Bool { stateui_web_event_number(0) != 0 }

    /// Calls `listener` each time the application's scripts tell `name`.
    static func listenToScript(_ name: String, _ listener: Int32) {
        utf8(name) { stateui_web_listen_script($0, $1, listener) }
    }

    /// Calls `element`'s own method `name`.
    static func callMethod(_ element: Int32, _ name: String) {
        utf8(name) { stateui_web_call_method(element, $0, $1) }
    }

    /// The number the event being heard carries in its `detail` - a custom element's, or a click's count.
    static var eventDetail: Double { stateui_web_event_number(0) }

    /// The words the event being heard carries in its `detail` - a custom element's own.
    static var eventWords: String { copyRead(length: stateui_web_event_words()) }

    /// The `<iframe>` `element` shows `source`: the address made for a document written in place; nil for an
    /// address shown.
    @discardableResult
    static func showInFrame(_ element: Int32, _ source: WebViewSource) -> String? {
        switch source {
        case .url(let address):
            utf8(address) { _ = stateui_web_frame_show(element, 0, $0, $1, nil, 0) }
            return nil
        case .html(let document, let base):
            let length = utf8(document) { words, length in
                utf8(base ?? "") { stateui_web_frame_show(element, 1, words, length, $0, $1) }
            }
            return copyRead(length: length)
        }
    }

    /// What the page can know of the frame's document: whether it is of the page's own site, and its history.
    static func frameState(_ element: Int32) -> (reachable: Bool, back: Bool, forward: Bool) {
        let state = stateui_web_frame_state(element)
        return (state & 1 != 0, state & 2 != 0, state & 4 != 0)
    }

    /// The frame's document's address where it is of the page's own site; "" where not.
    static func frameAddress(_ element: Int32) -> String {
        copyRead(length: stateui_web_frame_address(element))
    }

    /// A step of the frame's own - back, forward, the page again; whether it could take it.
    static func frameStep(_ element: Int32, _ step: Int32) -> Bool {
        stateui_web_frame_step(element, step) != 0
    }

    /// The JSON a script run in the frame's document answers; nil where it could not run.
    static func evaluateInFrame(_ element: Int32, _ script: String) -> String? {
        let length = utf8(script) { stateui_web_frame_evaluate(element, $0, $1) }
        return length < 0 ? nil : copyRead(length: length)
    }

    /// Shows the popover `element` under `anchor`, or beside it, else at `point` in the window.
    static func showPopover(
        _ element: Int32, under anchor: Int32 = 0, at point: Point = Point(x: 0, y: 0), beside: Bool = false
    ) {
        stateui_web_show_popover(element, anchor, point.x, point.y, beside ? 1 : 0)
    }

    static func hidePopover(_ element: Int32) {
        stateui_web_hide_popover(element)
    }

    /// Shows the `<dialog>` `element` over the page, modal; `closeModal` closes it.
    static func showModal(_ element: Int32) {
        stateui_web_show_modal(element)
    }

    static func closeModal(_ element: Int32) {
        stateui_web_close_modal(element)
    }

    /// Scrolls `element` into view, standing as `anchor` (`ScrollAnchor`'s number) says.
    static func scrollIntoView(_ element: Int32, anchor: Int32) {
        stateui_web_scroll_into_view(element, anchor)
    }

    /// The pointer of the event being heard goes on telling `element` until it lets go.
    static func capturePointer(_ element: Int32) {
        stateui_web_capture_pointer(element)
    }

    /// The event being heard no longer does what the page would do with it.
    static func takeEvent() {
        stateui_web_take_event()
    }

    static func observeSize(_ element: Int32, _ listener: Int32) {
        stateui_web_observe_size(element, listener)
    }

    /// Whether the browser lays `element` out: it stands in the page, and in no element shown as nothing.
    static func isLaidOut(_ element: Int32) -> Bool {
        stateui_web_is_laid_out(element) != 0
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

    /// Where each child stands in its layout, before any transform, by `(layout, child)` pairs; nil for a child laid
    /// out nowhere, and a layout's own size for a pair of it with itself.
    static func places(_ pairs: [(layout: Int32, child: Int32)]) -> [Rect?] {
        guard !pairs.isEmpty else { return [] }
        let flat = pairs.flatMap { [$0.layout, $0.child] }
        let read = flat.withUnsafeBufferPointer { list in
            numbers(pairs.count * 4) { stateui_web_read_places(list.baseAddress, Int32(pairs.count), $0) }
        }
        return (0..<pairs.count).map { index in
            let at = index * 4
            guard !read[at].isNaN else { return nil }
            return Rect(x: read[at], y: read[at + 1], width: read[at + 2], height: read[at + 3])
        }
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

    /// Draws a canvas's `numbers` and `words` (WebCanvasStroke) on the `<canvas>` element.
    static func drawCanvas(_ element: Int32, _ numbers: [Double], words: [String]) {
        utf8(words.joined(separator: "\u{0}")) { text, length in
            numbers.withUnsafeBufferPointer {
                stateui_web_draw_canvas(element, $0.baseAddress, Int32(numbers.count), text, length)
            }
        }
    }

    /// The local time of day.
    static var localTime: (hour: Int, minute: Int, second: Int, millisecond: Int) {
        let read = numbers(4) { stateui_web_local_time($0) }
        return (Int(read[0]), Int(read[1]), Int(read[2]), Int(read[3]))
    }

    /// The local time zone's name.
    static var localZone: String { copyRead(length: stateui_web_local_zone()) }

    /// How far `zone` - the local one where nil - is from UTC at noon on `day` - today where nil - in minutes; nil
    /// for a zone the browser does not know.
    static func utcOffset(of zone: String?, on day: CalendarDate?) -> Int? {
        let minutes = utf8(zone ?? "") {
            stateui_web_utc_offset($0, $1, Int32(day?.year ?? 0), Int32(day?.month ?? 0), Int32(day?.day ?? 0))
        }
        return minutes.isFinite ? Int(minutes) : nil
    }

    /// Tells a screen reader `words`.
    static func announce(_ words: String) {
        utf8(words) { stateui_web_announce($0, $1) }
    }

    /// Takes the focus off the field holding it; whether one held it.
    static func blurField() -> Bool { stateui_web_blur_field() != 0 }

    /// Puts the focus on `element` or the first in it that takes it; whether it holds it.
    static func focus(_ element: Int32) -> Bool { stateui_web_focus(element) != 0 }

    static func unfocus(_ element: Int32) {
        stateui_web_unfocus(element)
    }

    /// What the browser keeps under `key` for the page's site; "" for nothing.
    static func stored(_ key: String) -> String {
        copyRead(length: utf8(key) { stateui_web_stored($0, $1) })
    }

    /// Keeps `words` under `key` for the page's site; whether the browser could.
    static func store(_ words: String, under key: String) -> Bool {
        utf8(key) { key, keyLength in utf8(words) { stateui_web_store(key, keyLength, $0, $1) != 0 } }
    }

    /// The screen's smallest width where its user points by touch; 0 where by a mouse or a pen.
    static var touchScreen: Double { stateui_web_touch_screen() }

    /// Whether the user asked for less motion.
    static var reducesMotion: Bool { stateui_web_reduces_motion() != 0 }

    static func listenToAppearance(_ listener: Int32) {
        stateui_web_listen_appearance(listener)
    }

    /// The words the relay read last, `length` bytes of UTF-8.
    static func copyRead(length: Int32) -> String {
        guard length > 0 else { return "" }
        let bytes = [UInt8](unsafeUninitializedCapacity: Int(length)) { buffer, count in
            buffer.withMemoryRebound(to: CChar.self) { stateui_web_copy_read($0.baseAddress) }
            count = Int(length)
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// `text` as the relay reads words: its UTF-8 and their length.
    static func utf8<Result>(_ text: String, _ body: (UnsafePointer<CChar>?, Int32) -> Result) -> Result {
        var text = text
        return text.withUTF8 { bytes in
            bytes.withMemoryRebound(to: CChar.self) { body($0.baseAddress, Int32($0.count)) }
        }
    }
}
