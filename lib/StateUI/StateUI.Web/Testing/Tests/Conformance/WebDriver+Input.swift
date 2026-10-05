// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb
import WASILibc

/// What the user does to the page, as the browser takes it: the mouse pressed, moved and let go and its wheel turned,
/// keys and typed words - each through the browser's own input - and, where the browser takes no input a driver can
/// give, the DOM's own call a control answers: a slider's value, a list's choice, a day picked.
/// Design: docs/design/platforms/web/input.md
extension WebDriver {
    func perform(_ act: UserAct, on element: MountedElement) throws {
        if element.type == .toolbarItem, act == .activate { return try chooseAction(element) }
        if case .answer(let caption, let typing) = act { return try answer(caption, typing: typing, on: element) }
        // The browser's way back, over the page's own entry: from one it did not put there, the user leaves the site.
        if act == .goBack {
            guard try WebBrowser.truth("history.state?.stateui === true && (history.back(), true)", on: 0) else {
                throw DriverCannot(act, on: element)
            }
            return
        }
        let view = try self.view(of: element, act)
        let e = view.node
        switch (act, view) {
        case (.toggle, is WebSplitView): try click(try bar(over: element), part: "button[aria-label=Sidebar]")
        case (.toggle, _), (.activate, _): try click(view)
        case (.tap(let count), _): try click(view, count: count)
        case (.slide(let value), is WebSliderView):
            try WebBrowser.run("e.value = \(value); e.dispatchEvent(new Event('input', { bubbles: true })); "
                + "e.dispatchEvent(new Event('change', { bubbles: true }))", on: e)
        case (.step(let up), is WebStepperView):
            try click(e, part: up ? "button[aria-label=Increase]" : "button[aria-label=Decrease]")
        case (.enterWords(let words), is WebStepperView):
            try type(words, into: e, part: "input")
            press("Enter")
        case (.type(let words), is WebTextInputView): try type(words, into: e)
        case (.submit, is WebTextInputView):
            try WebBrowser.run("e.focus()", on: e)
            press("Enter")
        case (.focus, _): try WebBrowser.run("(e.matches('input, select, textarea, button') ? e : e.querySelector('input, select, textarea, button') ?? e).focus()", on: e)
        case (.choose(let place), is WebPickerView):
            try WebBrowser.run("e.selectedIndex = \(place); e.dispatchEvent(new Event('change', { bubbles: true }))", on: e)
        case (.choose(let place), is WebTabView):
            try click(e, part: ":scope > .stateui-tab-strip > [role=tab]:nth-child(\(place + 1))")
        case (.pickDate(let date), is WebDatePickerView):
            try pick(String(date.year).leftPadded(4) + "-" + String(date.month).leftPadded(2) + "-"
                + String(date.day).leftPadded(2), on: e)
        case (.pickTime(let time), is WebTimePickerView):
            try pick(String(time.hour).leftPadded(2) + ":" + String(time.minute).leftPadded(2) + ":"
                + String(time.second).leftPadded(2), on: e)
        case (.scroll(let offset), is WebScrollView):
            try WebBrowser.run("e.scrollTo(\(offset.x), \(offset.y))", on: e)
        case (.pressDown(let point), _): try mouse("mousePressed", at: point, on: e)
        case (.drag(let point), _): try mouse("mouseMoved", at: point, on: e, held: true)
        case (.lift(let point), _): try mouse("mouseReleased", at: point, on: e)
        case (.hover(let point), _): try mouse("mouseMoved", at: point, on: e)
        case (.leave, _): try leave(e)
        case (.pan(let offset), _): try pan(e, by: offset)
        case (.pinch(let scale, let share), _): try pinch(e, by: scale, at: share)
        default: throw DriverCannot(act, on: element)
        }
    }

    // MARK: - The mouse

    /// A script finding the element `e`, or its part `part` names.
    private func target(_ part: String?) -> String {
        part.map { "e.querySelector(\(WebBrowser.quoted($0)))" } ?? "e"
    }

    /// Where the element `e` - or its part `part` names - stands in the browser's window, brought into it first.
    func box(of e: Int32, part: String? = nil) throws -> Rect {
        let numbers = try numbers(
            "((t) => t && (t.scrollIntoView({ block: 'nearest', inline: 'nearest' }), stateui.box(t)))(\(target(part)))",
            on: e)
        guard numbers.count == 4 else { throw DriverCannot("find \(part ?? "an element") on the page") }
        return Rect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    /// The mouse clicks `view` in its middle, `count` times in a run.
    func click(_ view: WebDOMView, count: Int = 1) throws {
        try click(view.node, count: count)
    }

    /// The mouse clicks the element `e` - or its part `part` names - in its middle, `count` times in a run.
    func click(_ e: Int32, part: String? = nil, count: Int = 1) throws {
        let box = try box(of: e, part: part)
        let middle = Point(x: box.width / 2, y: box.height / 2)
        for each in 1...max(count, 1) {
            mouse("mousePressed", at: middle, in: box, count: each)
            mouse("mouseReleased", at: middle, in: box, count: each)
        }
    }

    /// The mouse's `type` of event at `point` of the element `e`.
    private func mouse(_ type: String, at point: Point, on e: Int32, held: Bool = false) throws {
        mouse(type, at: point, in: try box(of: e), held: held)
    }

    /// The mouse's `type` of event at `point` of what stands in `box`.
    func mouse(
        _ type: String, at point: Point, in box: Rect, count: Int = 1, held: Bool = false, wheel: Double = 0,
        modifiers: Int = 0
    ) {
        WebBrowser.ask([
            ("mouse", .words(type)), ("x", .number(box.x + point.x)), ("y", .number(box.y + point.y)),
            ("count", .number(Double(count))), ("held", .truth(held)), ("deltaY", .number(wheel)),
            ("modifiers", .number(Double(modifiers))),
        ])
    }

    /// The pointer leaves the element `e`, for a place beside it.
    private func leave(_ e: Int32) throws {
        let box = try box(of: e)
        let beside = box.x + box.width + 30 < 1280 ? box.width + 30 : -30
        mouse("mouseMoved", at: Point(x: beside, y: box.height / 2), in: box)
    }

    /// A press dragged across the element `e` by `offset` from its middle, and let go.
    private func pan(_ e: Int32, by offset: Point) throws {
        let box = try box(of: e)
        let middle = Point(x: box.width / 2, y: box.height / 2)
        mouse("mousePressed", at: middle, in: box)
        for share in [0.25, 0.5, 0.75, 1.0] {
            mouse("mouseMoved", at: Point(x: middle.x + offset.x * share, y: middle.y + offset.y * share), in: box,
                  held: true)
        }
        mouse("mouseReleased", at: Point(x: middle.x + offset.x, y: middle.y + offset.y), in: box)
    }

    /// Two fingers spread or closed over the element `e` by `scale`, about a point given as a share of its size: a
    /// trackpad's pinch, which the browser gives as the wheel turned with Control held.
    private func pinch(_ e: Int32, by scale: Double, at share: Point) throws {
        let box = try box(of: e)
        mouse("mouseWheel", at: Point(x: box.width * share.x, y: box.height * share.y), in: box,
              wheel: -100 * log(scale), modifiers: 2)
    }

    // MARK: - The keyboard

    /// Types `words` into the field `e` - or its part `part` names - as the keyboard leaves them: what does not lead
    /// to them chosen and deleted, the rest typed after what does.
    private func type(_ words: String, into e: Int32, part: String? = nil) throws {
        let field = target(part)
        let held = try WebBrowser.evaluate("((t) => (t.focus(), t.value))(\(field))", on: e) ?? ""
        let kept = words.hasPrefix(held) ? held : ""
        if kept.isEmpty, !held.isEmpty {
            try WebBrowser.run("\(field).select()", on: e)
            press("Backspace")
        } else {
            try WebBrowser.run("((t) => t.setSelectionRange?.(t.value.length, t.value.length))(\(field))", on: e)
        }
        let rest = String(words.dropFirst(kept.count))
        if !rest.isEmpty { WebBrowser.ask([("insertText", .words(rest))]) }
    }

    /// The key `key` pressed and let go.
    func press(_ key: String) {
        WebBrowser.ask([("key", .words(key))])
    }

    // MARK: - The DOM's own calls

    /// A day or a time picked on the input `e`, as its own picker leaves it.
    private func pick(_ value: String, on e: Int32) throws {
        try WebBrowser.run("e.value = \(WebBrowser.quoted(value)); e.dispatchEvent(new Event('input', { bubbles: true })); "
            + "e.dispatchEvent(new Event('change', { bubbles: true }))", on: e)
    }

    /// The element of the bar of the window `element` stands in.
    func bar(over element: MountedElement) throws -> Int32 {
        guard let bar = renderer?.roster.controllers.first?.window.bar else { throw DriverCannot("find the window's bar") }
        return bar.node
    }
}

extension String {
    /// The number's digits, zeros before them up to `count`.
    func leftPadded(_ count: Int) -> String {
        String(repeating: "0", count: max(0, count - self.count)) + self
    }
}
