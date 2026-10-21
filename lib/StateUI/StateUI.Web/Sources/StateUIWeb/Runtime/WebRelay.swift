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
        nameKeys()
    }

    /// Tells the relay the page's name of each key writing no character, by its number: Swift's names alone.
    private static func nameKeys() {
        let named = WebKeys.names.sorted { $0.key.rawValue < $1.key.rawValue }
        let numbers = named.map { Double($0.key.rawValue) }
        utf8(named.map(\.value).joined(separator: "\u{0}")) { text, length in
            numbers.withUnsafeBufferPointer { stateui_web_name_keys($0.baseAddress, Int32(numbers.count), text, length) }
        }
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

    /// How many listeners the page can call now: what a test counts to see nothing outlived its view.
    static var listenerCount: Int { listeners.count }

    /// Lets go of the listener `number`, and the relay of whatever it hung for it.
    static func forget(_ number: Int32) {
        listeners[number] = nil
        stateui_web_forget(number)
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

    /// Calls `listener` whenever the relay hears `kind` on the element.
    static func hear(_ element: Int32, _ kind: WebHearing, _ listener: Int32) {
        stateui_web_hear(element, kind.rawValue, listener)
    }

    /// Calls `listener` as the user asks for the element's menu: a right click, or a finger held still.
    static func listenForMenu(_ element: Int32, _ listener: Int32) {
        stateui_web_listen_menu(element, HandReading.hold, WebPress.finger, listener)
    }

    /// The number at `index` of the event being heard - what a listener of its kind is told.
    static func eventNumber(_ index: Int) -> Double { stateui_web_event_number(Int32(index)) }

    /// How many clicks the event being heard counts.
    static var eventClicks: Int { Int(stateui_web_event_number(0)) }

    /// Where the pointer of the event being heard is, from the listening element's top left corner.
    static var eventPoint: Point { Point(x: stateui_web_event_number(1), y: stateui_web_event_number(2)) }

    /// The pointer of the event being heard: its number, where it is on the page, its kind and its button.
    static var eventPointer: (id: Int, at: Point, kind: WebPress.Pointer, button: Int) {
        (Int(stateui_web_event_number(3)), Point(x: stateui_web_event_number(4), y: stateui_web_event_number(5)),
         WebPress.Pointer(rawValue: Int32(stateui_web_event_number(6))) ?? .mouse, Int(stateui_web_event_number(7)))
    }

    /// The wheel's turn down of the event being heard, and whether a key made it a pinch.
    static var eventWheel: (down: Double, pinches: Bool) {
        (stateui_web_event_number(8), stateui_web_event_number(9) != 0)
    }

    /// The scale of the gesture being heard, from 1 as it began.
    static var eventScale: Double { stateui_web_event_number(10) }

    /// How far the gesture being heard has turned since it began, in degrees clockwise.
    static var eventRotation: Double { stateui_web_event_number(19) }

    /// Whether ⌥/Alt was held as the event being heard happened.
    static var eventAlt: Bool { stateui_web_event_number(20) != 0 }

    /// Whether an input method was composing the words as the event being heard happened.
    static var eventComposing: Bool { stateui_web_event_number(21) != 0 }

    /// The size of the element hearing the event.
    static var eventSize: LayoutSize {
        LayoutSize(width: stateui_web_event_number(11), height: stateui_web_event_number(12))
    }

    /// Whether the click being heard fell on a label beside its control, which the browser clicks next.
    static var eventPassesToControl: Bool { stateui_web_event_number(13) != 0 }

    /// The wheel's turn across and down of the event being heard, in pixels.
    static var eventScroll: Point { Point(x: stateui_web_event_number(14), y: stateui_web_event_number(15)) }

    /// When the event being heard happened, in the page's milliseconds - the frame clock's own.
    static var eventTime: Double { stateui_web_event_number(16) }

    /// The notches of the wheel the event being heard turned, a notch an event across and down, the way they move
    /// what is under the hand - where the browser measures the wheel in lines or pages; nil where in pixels.
    static var eventNotches: Point? {
        guard stateui_web_event_number(17) != 0 else { return nil }

        func notch(_ turn: Double) -> Double { turn > 0 ? -1 : turn < 0 ? 1 : 0 }
        return Point(x: notch(stateui_web_event_number(18)), y: notch(stateui_web_event_number(8)))
    }

    /// Calls `listener` as `element` comes near the view of the scroller `root`, and as it goes away - the scroller's
    /// one listener, once for every element a frame saw (`eventNearness`).
    static func watchNearness(_ element: Int32, of root: Int32, _ listener: Int32) {
        stateui_web_watch_nearness(element, root, listener)
    }

    /// The elements the nearness being heard is of, each with whether it came near.
    static var eventNearness: [(element: Int32, near: Bool)] {
        (0..<Int(stateui_web_event_number(0))).map { index in
            (Int32(stateui_web_event_number(Int32(1 + 2 * index))), stateui_web_event_number(Int32(2 + 2 * index)) != 0)
        }
    }

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
            utf8(address) { _ = stateui_web_frame_show(element, FrameSource.address.rawValue, $0, $1) }
            return nil
        case .html(let words, let base):
            let length = utf8(WebDocument.document(words, base: base)) {
                stateui_web_frame_show(element, FrameSource.document.rawValue, $0, $1)
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

    /// A step of the frame's own; whether it could take it.
    static func frameStep(_ element: Int32, _ step: FrameStep) -> Bool {
        stateui_web_frame_step(element, step.rawValue) != 0
    }

    /// What a frame is given to show: an address, or a document written in place.
    enum FrameSource: Int32 {
        case address = 0
        case document
    }

    /// A step of a frame's own: back, forward, or the page again.
    enum FrameStep: Int32 {
        case back = 0
        case forward
        case reload
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

    /// Whether the page stands on one of Apple's platforms, whose shortcuts Command takes.
    static var onApple: Bool { stateui_web_apple() != 0 }

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

    /// Whether the style sheet stands `element` over its siblings, out of its parent's flow.
    static func standsOver(_ element: Int32) -> Bool {
        stateui_web_stands_over(element) != 0
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

    /// The page wears `colour` under its window, and keeps it for its next start, under the system's light or dark;
    /// nil wears and keeps none.
    static func keepPageColour(_ colour: String?) {
        utf8(colour ?? "") { stateui_web_keep_page_colour($0, $1) }
    }

    static func setTitle(_ title: String) {
        utf8(title) { stateui_web_set_title($0, $1) }
    }

    /// The site's name the page's head gives, its `application-name`; "" where it gives none.
    static var siteName: String { copyRead(length: stateui_web_site_name()) }

    static func requestFrame() {
        stateui_web_request_frame()
    }

    /// Asks the page to call once more after `milliseconds`, in place of the call asked for before.
    static func wake(after milliseconds: Double) {
        stateui_web_wake_after(milliseconds)
    }

    static var now: Double { stateui_web_now() }

    static var prefersDark: Bool { stateui_web_prefers_dark() != 0 }

    /// The accent the browser draws its own controls in, as ARGB.
    static var accentColor: UInt32 { UInt32(bitPattern: stateui_web_accent_color()) }

    /// Shows the page in `theme`: the root's colour scheme, which the browser's controls and the host's colours
    /// follow; none for the system's.
    static func useColorScheme(_ theme: ColorScheme) {
        stateui_web_use_color_scheme(theme.rawValue)
    }

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

    /// How far `zone` - the local one where nil - is from UTC at noon on `day` - now where nil - in minutes; nil
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

    /// Offers `text` and `link` - each where given - to the browser's share sheet, `listener` told once it answers:
    /// event 1 and "1" shared or "0" cancelled, or 0 and why not, read by `file_words`.
    static func share(text: String?, link: String?, _ listener: Int32) {
        utf8(text ?? "") { words, wordsLength in
            utf8(link ?? "") { address, addressLength in
                stateui_web_share(words, text == nil ? -1 : wordsLength, address, link == nil ? -1 : addressLength, listener)
            }
        }
    }

    /// Puts `words` on the browser's clipboard, where the page may write it.
    static func writeClipboard(_ words: String) {
        utf8(words) { stateui_web_clipboard_write($0, $1) }
    }

    /// Reads the browser's clipboard, `listener` told once it answers: event 1 and its words, or 0 and why not, both
    /// read by `file_words`.
    static func readClipboard(_ listener: Int32) {
        stateui_web_clipboard_read(listener)
    }

    /// Takes the focus off the field holding it; whether one held it.
    static func blurField() -> Bool { stateui_web_blur_field() != 0 }

    /// Puts the focus on `element` or the first in it that takes it; whether it holds it.
    static func focus(_ element: Int32) -> Bool { stateui_web_focus(element) != 0 }

    /// Does an Edit menu's own entry to the field the user last typed into, which takes the focus back.
    /// Design: docs/design/platforms/web/pages.md#the-edit-menu
    static func edit(_ command: EditCommand) {
        stateui_web_edit(Int32(EditCommand.allCases.firstIndex(of: command) ?? 0))
    }

    static func unfocus(_ element: Int32) {
        stateui_web_unfocus(element)
    }

    /// Whether `element`, or one in it, holds the focus.
    static func holdsFocus(_ element: Int32) -> Bool { stateui_web_holds_focus(element) != 0 }

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

    /// Whether the user asked for more contrast.
    static var prefersMoreContrast: Bool { stateui_web_prefers_more_contrast() != 0 }

    /// Calls `listener` whenever less motion or more contrast is asked for, or no longer.
    static func listenToAccessibility(_ listener: Int32) {
        stateui_web_listen_accessibility(listener)
    }

    static func listenToAppearance(_ listener: Int32) {
        stateui_web_listen_appearance(listener)
    }

    /// The user's locale as the browser has it, word by word (`WebEnvironment.locale`).
    static var localeWords: [String] {
        copyRead(length: stateui_web_locale_words()).split(separator: "\u{0}", omittingEmptySubsequences: false)
            .map(String.init)
    }

    /// Calls `listener` whenever the user's languages change.
    static func listenToLocale(_ listener: Int32) {
        stateui_web_listen_locale(listener)
    }

    /// Calls `listener` whenever the screen's density turns - a window moved to another screen, the page zoomed.
    static func listenToDensity(_ listener: Int32) {
        stateui_web_listen_density(listener)
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
