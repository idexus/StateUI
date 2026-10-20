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
    /// A shortcut pressed while the page has the keyboard: the key-down the browser raises for it, on what holds the
    /// keyboard.
    private func pressKeys(_ shortcut: KeyboardShortcut) throws {
        let onApple = try WebBrowser.truth("/Mac|iPhone|iPad|iPod/.test(navigator.platform ?? '')", on: 0)
        let key = shortcut.key.character.map { String($0) } ?? shortcut.key.named.flatMap { WebKeys.names[$0] } ?? ""
        let code = shortcut.key.character.map { $0.isNumber ? "Digit\($0)" : "Key\(String($0).uppercased())" } ?? key
        let primary = shortcut.modifiers.contains(.primary)
        try WebBrowser.run("""
            (document.activeElement ?? document.body).dispatchEvent(new KeyboardEvent("keydown", { key: "\(key)", code: "\(code)", bubbles: true,
              cancelable: true, metaKey: \(primary && onApple), ctrlKey: \(primary && !onApple),
              shiftKey: \(shortcut.modifiers.contains(.shift)), altKey: \(shortcut.modifiers.contains(.alt)) }))
            """)
    }

    func perform(_ act: UserAct, on element: MountedElement) throws {
        if element.type == .toolbarItem, act == .activate { return try chooseAction(element) }
        if element.type == .menuItem, act == .activate { return try choose(element) }
        if let page = Self.pageState(after: act) { return try running().pageChanged(page) }
        if act == .close, element.type == .window { return try running().runtime.ending() }
        if case .answer(let button, let typing) = act { return try answer(button, typing: typing, on: element) }
        if case .answerFiles(let names) = act { return try answerFiles(names, on: element) }
        if case .dragAndDrop(let target, let across) = act { return try dragAndDrop(element, onto: target, across: across) }
        if case .dropFiles(let names) = act { return try dropFiles(names, on: element) }
        if case .pressKeys(let shortcut) = act { return try pressKeys(shortcut) }
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
        case (.toggle, is WebSplitView): try click(try bar(over: element), part: "button:has(> [data-glyph=sidebar])")
        case (.activate, _) where try isBehindAQuestion(e):
            // The user reaches nothing under a question; the program's own may wait their turn behind it.
            try WebBrowser.run("e.click()", on: e)
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
        case (.choose(let place), is WebChoiceGroupView):
            try WebBrowser.run("e.children[\(place)].click()", on: e)
        case (.choose(let place), is WebPickerView):
            // The title's option stands first.
            try WebBrowser.run("e.selectedIndex = \(place + 1); e.dispatchEvent(new Event('change', { bubbles: true }))", on: e)
        case (.choose(let place), is WebTabView):
            try click(e, part: ":scope > .stateui-tab-strip > [role=tab]:nth-child(\(place + 1))")
        case (.pickDate(let date), is WebDatePickerView):
            try pick(String(date.year).leftPadded(4) + "-" + String(date.month).leftPadded(2) + "-"
                + String(date.day).leftPadded(2), on: e)
        case (.pickTime(let time), is WebTimePickerView):
            try pick(String(time.hour).leftPadded(2) + ":" + String(time.minute).leftPadded(2) + ":"
                + String(time.second).leftPadded(2), on: e)
        case (.choose(let place), is WebItemsView):
            let item = "[...e.querySelectorAll(':scope > .stateui-items-content > .stateui-item:not([data-part])')][\(place)]"
            guard let node = try WebBrowser.number("((c) => c ? stateui.numberOf(c) : null)(\(item))", on: e) else {
                throw DriverCannot(act, on: element)
            }
            try click(Int32(node))
        case (.scroll(let offset), is WebItemsView):
            try WebBrowser.run("e.scrollTo(\(offset.x), \(offset.y))", on: e)
            WebBrowser.pause()
        case (.scroll(let offset), is WebScrollView):
            // The browser says a scroll on its next frame.
            try WebBrowser.run("e.scrollTo(\(offset.x), \(offset.y))", on: e)
            WebBrowser.pause()
        case (.pressDown(let point), _): try mouse("mousePressed", at: point, on: e)
        case (.drag(let point), _): try mouse("mouseMoved", at: point, on: e, held: true)
        case (.lift(let point), _): try mouse("mouseReleased", at: point, on: e)
        case (.hover(let point), _): try mouse("mouseMoved", at: point, on: e)
        case (.leave, _): try leave(e)
        case (.pan(let offset), _): try pan(e, by: offset)
        // A throw's speed is the events' times, which input the driver sends carries as the browser receives it:
        // the hand reaches the host's entry as the pointer would hand it, with the speed - ✓.
        case (.sweep(let offset, let speed), _):
            guard let web = element.native as? WebElement, web.hand(.began, moved: .zero, at: nil) else {
                throw DriverCannot(act, on: element)
            }
            web.hand(.changed, moved: offset, at: nil)
            web.hand(.ended, moved: .zero, speed: speed, at: nil)
        // A wheel's notches reach the host's entry as a wheel measured in lines would hand them - ✓.
        case (.notch(let notches), _):
            guard let web = element.native as? WebElement, web.notched(notches) else { throw DriverCannot(act, on: element) }
        case (.pinch(let scale, let share), _): try pinch(e, by: scale, at: share)
        case (.rotate(let degrees, let share), _): try rotate(e, by: degrees, at: share)
        default: throw DriverCannot(act, on: element)
        }
    }

    /// `element` dragged onto the view of id `target` - across the one of id `across` first - by the DOM's drag
    /// events, one `DataTransfer` carried through them, in a turn of the page's own: the drag starts, comes over the
    /// view crossed and goes, comes over the target and is let go there, and ends.
    func dragAndDrop(_ element: MountedElement, onto target: String, across: String?) throws {
        let act = UserAct.dragAndDrop(onto: target, across: across)
        func mark(_ id: String?, as role: String) throws {
            let found = id.map { renderer?.runtime.tree.root?.first(id: .manual($0)) } ?? element
            guard let node = (found?.native as? WebElement)?.view?.node else { throw DriverCannot(act, on: element) }
            try WebBrowser.run("e.dataset.stateuiDrag = '\(role)'", on: node)
        }
        try mark(nil, as: "source")
        try mark(target, as: "target")
        if let across { try mark(across, as: "crossed") }
        try WebBrowser.run("""
            const at = (role) => document.querySelector(`[data-stateui-drag="${role}"]`);
            const carried = new DataTransfer();
            const tell = (role, name) => at(role)?.dispatchEvent(
                new DragEvent(name, { bubbles: true, cancelable: true, dataTransfer: carried }));
            const steps = [["source", "dragstart"]];
            if (at("crossed")) steps.push(["crossed", "dragenter"], ["crossed", "dragover"], ["crossed", "dragleave"]);
            steps.push(["target", "dragenter"], ["target", "dragover"], ["target", "drop"], ["source", "dragend"]);
            steps.forEach(([role, name], index) => setTimeout(() => {
                tell(role, name);
                if (index === steps.length - 1) {
                    for (const marked of document.querySelectorAll("[data-stateui-drag]")) delete marked.dataset.stateuiDrag;
                }
            }, 0))
            """, on: 0)
    }

    /// Files of `names` dragged from the system onto `element` and let go there, by the DOM's drag events carrying
    /// them, in a turn of the page's own.
    func dropFiles(_ names: [String], on element: MountedElement) throws {
        guard let node = (element.native as? WebElement)?.view?.node else { throw DriverCannot(.dropFiles(names), on: element) }
        let files = names.map { "new File([\(WebBrowser.quoted($0))], \(WebBrowser.quoted($0)))" }.joined(separator: ", ")
        try WebBrowser.run("""
            const carried = new DataTransfer();
            for (const file of [\(files)]) carried.items.add(file);
            for (const name of ["dragenter", "dragover", "drop"]) {
                setTimeout(() => e.dispatchEvent(new DragEvent(name, { bubbles: true, cancelable: true, dataTransfer: carried })), 0);
            }
            """, on: node)
    }

    /// Whether the element `e` stands under a question the page shows over it.
    private func isBehindAQuestion(_ e: Int32) throws -> Bool {
        try WebBrowser.truth("((q) => !!q && !q.contains(e))(document.querySelector('dialog.stateui-question[open]'))", on: e)
    }

    /// What the page stands as after each act on its window, as the browser would tell it: whether its tab shows,
    /// whether it holds the keyboard.
    static func pageState(after act: UserAct) -> (shown: Bool, focused: Bool)? {
        switch act {
        case .switchAway: (true, false)
        case .switchBack, .restore: (true, true)
        case .minimize: (false, false)
        default: nil
        }
    }

    // MARK: - The mouse

    /// A script finding the element `e`, or its part `part` names.
    private func target(_ part: String?) -> String {
        part.map { "e.querySelector(\(WebBrowser.quoted($0)))" } ?? "e"
    }

    /// Where the element `e` - or its part `part` names - stands in the browser's window, brought into it first, once
    /// the page's pictures have come and stand at their size: one coming moves what stands after it, as the user sees.
    func box(of e: Int32, part: String? = nil) throws -> Rect {
        // A picture is come once loaded and sized by it - the host sizes it as it hears it loaded.
        let come = "[...document.images].every((i) => i.complete && (!i.classList.contains('stateui-picture') "
            + "|| !i.getAttribute('src') || i.style.containIntrinsicSize !== ''))"
        for _ in 0..<150 {
            guard try !WebBrowser.truth(come, on: 0) else { break }
            WebBrowser.pause()
        }
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

    /// The mouse clicks the element `e` - or its part `part` names - in its middle, `count` times in a run, aimed as
    /// the user aims: at it where it stands once nothing moving over it - a picture arriving above it - is there.
    func click(_ e: Int32, part: String? = nil, count: Int = 1) throws {
        var box = try box(of: e, part: part)
        let aimed = "((t, b) => t && t.contains(document.elementFromPoint(b.x + b.width / 2, b.y + b.height / 2)))"
            + "(\(target(part)), \(target(part))?.getBoundingClientRect())"
        for _ in 0..<30 {
            guard try !WebBrowser.truth(aimed, on: e) else { break }
            WebBrowser.pause()
            box = try self.box(of: e, part: part)
        }
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
        modifiers: Int = 0, button: String = "left"
    ) {
        WebBrowser.ask([
            ("mouse", .words(type)), ("x", .number(box.x + point.x)), ("y", .number(box.y + point.y)),
            ("count", .number(Double(count))), ("held", .truth(held)), ("deltaY", .number(wheel)),
            ("modifiers", .number(Double(modifiers))), ("button", .words(button)),
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

    /// Two fingers spread or closed over the element `e` by `scale`, about a point given as a share of its size, and
    /// lifted: touches the browser takes as its own, on whole pixels, 20 px apart and both on the view, one finger
    /// moved in one step so the pinch's one step is `scale`, their middle then at the point.
    private func pinch(_ e: Int32, by scale: Double, at share: Point) throws {
        let box = try box(of: e)
        let middle = Point(x: box.x + box.width * share.x, y: box.y + box.height * share.y)
        let still = Point(x: middle.x - 10 * scale, y: middle.y)
        touch("touchStart", [still, Point(x: still.x + 20, y: middle.y)])
        touch("touchMove", [still, Point(x: still.x + 20 * scale, y: middle.y)])
        touch("touchEnd", [])
    }

    /// Two fingers turned clockwise over the element `e` by `degrees` about a point given as a share of its size, and
    /// lifted: touches the browser takes as its own, 80 px apart across, turned in four steps.
    private func rotate(_ e: Int32, by degrees: Double, at share: Point) throws {
        let box = try box(of: e)
        let middle = Point(x: box.x + box.width * share.x, y: box.y + box.height * share.y)
        func fingers(_ turned: Double) -> [Point] {
            let (across, down) = (40 * cos(turned * .pi / 180), 40 * sin(turned * .pi / 180))
            return [Point(x: middle.x - across, y: middle.y - down), Point(x: middle.x + across, y: middle.y + down)]
        }
        touch("touchStart", fingers(0))
        for step in 1...4 { touch("touchMove", fingers(degrees * Double(step) / 4)) }
        touch("touchEnd", [])
    }

    /// The browser's touch of `type`, its fingers at `points` in its window.
    private func touch(_ type: String, _ points: [Point]) {
        WebBrowser.ask([("touch", .words(type)), ("points", .points(points))])
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
