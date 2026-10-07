// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb

/// The facts the Web driver reads besides a member - the keyboard's focus, what a press reaches, where a view stands,
/// the question showing, what assistive technology was told, the log, what is kept, the bar - and the bar's actions
/// chosen and a question answered, as the user does.
/// Design: docs/design/host/conformance.md#the-driver
extension WebDriver {
    func focused(_ element: MountedElement) throws -> Bool {
        let view = try self.view(of: element, reading: .frame)
        return try WebBrowser.truth("e.contains(document.activeElement)", on: view.node)
    }

    func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        let view = try self.view(of: element, reading: .frame)
        return try WebBrowser.truth("""
            ((box) => ((hit) => !!hit && e.contains(hit))(document.elementFromPoint(box.x + \(point.x), box.y + \(point.y))))\
            (e.getBoundingClientRect())
            """, on: view.node)
    }

    /// The layout's children by where the page paints each one's node among the layout node's children: by its
    /// z-index, then its place in the document - the last painted last.
    func drawingOrder(of layout: MountedElement) throws -> [MountedElement] {
        let cannot = DriverCannot("read the drawing order of \(layout.type.name)")
        guard let parent = (layout.native as? WebElement)?.view else { throw cannot }
        try WebBrowser.run("window.stateuiLayout = e", on: parent.node)
        return try layout.children.map { child in
            guard let node = (child.native as? WebElement)?.view?.node else { throw cannot }
            let key = try numbers("""
                ((n) => { const p = window.stateuiLayout; while (n && n.parentElement !== p) n = n.parentElement; \
                return n ? [parseInt(getComputedStyle(n).zIndex) || 0, [...p.children].indexOf(n)] : []; })(e)
                """, on: node)
            guard key.count == 2 else { throw cannot }
            return (child, key[0], key[1])
        }
        .sorted { ($0.1, $0.2) < ($1.1, $1.2) }.map(\.0)
    }

    func place(of element: MountedElement) throws -> Rect {
        let view = try self.view(of: element, reading: .frame)
        let numbers = try numbers("stateui.box(e)", on: view.node)
        guard numbers.count == 4 else { throw DriverCannot("read where \(element.type.name) stands") }
        return Rect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    /// The colour the window shows at `point` of `element`, where it differs from what shows there without the
    /// element: the page's own picture, a pixel of it read with the element and again with it unseen - which lays
    /// nothing out anew.
    func color(of element: MountedElement, at point: Point) throws -> Color? {
        guard let view = (element.native as? WebElement)?.view else { throw DriverCannot("read the colour of \(element.type.name)") }
        let box = try box(of: view.node)
        let at = Point(x: box.x + point.x, y: box.y + point.y)
        let shown = try pixel(at)
        try WebBrowser.run("e.dataset.stateuiSeen = e.style.visibility; e.style.visibility = 'hidden'", on: view.node)
        let behind = try pixel(at)
        try WebBrowser.run("e.style.visibility = e.dataset.stateuiSeen; delete e.dataset.stateuiSeen", on: view.node)
        return shown == behind ? nil : shown
    }

    /// The colour of the window's picture at `point` in it.
    private func pixel(_ point: Point) throws -> Color {
        let channels = (WebBrowser.ask([("pixel", .points([point]))]) ?? "").split(separator: ",").compactMap { Int($0) }
        guard channels.count == 4 else { throw DriverCannot("read the window's picture") }
        return Color(red: channels[0], green: channels[1], blue: channels[2], alpha: channels[3])
    }

    func question(over element: MountedElement) throws -> Question? {
        let shown = "document.querySelector('dialog.stateui-question[open]')"
        guard try WebBrowser.truth("!!\(shown)", on: 0) else { return nil }
        let title = try WebBrowser.evaluate("\(shown).querySelector('h2')?.textContent ?? ''", on: 0) ?? ""
        let message = try WebBrowser.evaluate("\(shown).querySelector('p')?.textContent ?? ''", on: 0) ?? ""
        let buttons = try words("[...\(shown).querySelectorAll('button')].map((b) => b.textContent)", on: 0)
        let field = try WebBrowser.evaluate("\(shown).querySelector('input')?.value", on: 0)
        return Question(title: title, message: message, buttons: buttons, field: field)
    }

    /// The question showing answered by its button of `caption`, its field first holding `typing`.
    func answer(_ caption: String, typing: String?, on element: MountedElement) throws {
        let shown = "document.querySelector('dialog.stateui-question[open]')"
        guard try WebBrowser.truth("!!\(shown)", on: 0) else { throw DriverCannot(.answer(caption, typing: typing), on: element) }
        if let typing {
            try WebBrowser.run("\(shown).querySelector('input').focus(); \(shown).querySelector('input').select()")
            if typing.isEmpty { press("Backspace") } else { WebBrowser.ask([("insertText", .words(typing))]) }
        }
        let place = try WebBrowser.number(
            "[...\(shown).querySelectorAll('button')].findIndex((b) => b.textContent === \(WebBrowser.quoted(caption)))",
            on: 0) ?? -1
        guard place >= 0 else { throw DriverCannot("find the answer \(caption)") }
        let numbers = try numbers("stateui.box(\(shown).querySelectorAll('button')[\(Int(place))])", on: 0)
        guard numbers.count == 4 else { throw DriverCannot("find the answer \(caption)") }
        let box = Rect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
        mouse("mousePressed", at: Point(x: box.width / 2, y: box.height / 2), in: box)
        mouse("mouseReleased", at: Point(x: box.width / 2, y: box.height / 2), in: box)
    }

    /// The file dialog the relay holds: one that opens or one that saves.
    func fileDialog(over element: MountedElement) throws -> FileDialog? {
        switch try WebBrowser.evaluate("stateui.fileDialog?.kind ?? ''", on: 0) {
        case "open": .open
        case "save": .save
        default: nil
        }
    }

    /// The file dialog the relay holds answered as the user does, by the driver's files of `names` - none cancels it -
    /// in a turn of the page's own.
    func answerFiles(_ names: [String], on element: MountedElement) throws {
        let chosen = names.map(WebBrowser.quoted).joined(separator: ",")
        let answering = "(d) => !!d && (stateui.fileDialog = null, setTimeout(() => d.answer([\(chosen)]), 0), true)"
        guard try WebBrowser.truth("(\(answering))(stateui.fileDialog)", on: 0) else {
            throw DriverCannot(.answerFiles(names), on: element)
        }
    }

    /// What the relay would have opened, in order: an address as written, a file by its name.
    func launched() throws -> [String] {
        try words("stateui.launched", on: 0)
    }

    /// Empties the driver's files, the dialog held and what was launched, as each case starts.
    func emptyFiles() {
        try? WebBrowser.run("stateui.files = new Map(); stateui.fileDialog = null; stateui.launched = []")
    }

    /// The colour scheme the page's root stands in: the one it holds, else the system's.
    func theme() throws -> ColorScheme {
        let held = try WebBrowser.evaluate("getComputedStyle(document.documentElement).colorScheme", on: 0) ?? ""
        if held == "dark" { return .dark }
        if held == "light" { return .light }
        return try WebBrowser.truth("matchMedia('(prefers-color-scheme: dark)').matches", on: 0) ? .dark : .light
    }

    /// What assistive technology was told, a few frames given for the page's live region to say it.
    func announced() throws -> [String] {
        for _ in 0..<10 where try words("stateui.announced", on: 0).isEmpty { WebBrowser.pause() }
        return try words("stateui.announced", on: 0)
    }

    func kept(_ key: String, inScene: Bool) throws -> HostValue? {
        if inScene {
            let scenes = try WebBrowser.evaluate("localStorage.getItem('StateUI kept scenes: Conformance')", on: 0)
            return KeptScenes(scenes ?? "").scenes.first?.values[key]
        }
        let words = try WebBrowser.evaluate("localStorage.getItem('StateUI kept values: Conformance')", on: 0) ?? ""
        let kept = KeptValuesText(words)
        let kinds = [
            PersistentKey(key, of: String.self), PersistentKey(key, of: Double.self), PersistentKey(key, of: Int.self),
            PersistentKey(key, of: Bool.self),
        ]
        return kinds.lazy.compactMap { kept.restored(for: [$0])[key] }.first
    }

    /// The bar's action of the toolbar item `element` chosen, as the user's click does - one behind the bar chosen
    /// from the menu its More opens.
    func chooseAction(_ element: MountedElement) throws {
        if let button = try barButtons().first(where: { $0.item === element }) { return try click(button) }
        guard let item = try behindTheBar(element) else { throw DriverCannot(.activate, on: element) }
        try click(item)
    }

    /// The button of the toolbar item `element` in the menu behind the bar, opened; nil where it stands there not.
    func behindTheBar(_ element: MountedElement) throws -> Int32? {
        let caption = element.value(.text)?.string ?? ""
        try click(try bar(over: element), part: "button[aria-label=More]")
        let script = "((m) => ((b) => b ? stateui.numberOf(b) : null)(m && [...m.children].find((c) => "
            + "[...c.querySelectorAll('span')].pop()?.textContent === \(WebBrowser.quoted(caption)))))"
            + "([...document.querySelectorAll('.stateui-menu')].find((m) => m.matches(':popover-open')))"
        guard let node = try WebBrowser.number(script, on: 0) else {
            press("Escape")
            return nil
        }
        return Int32(node)
    }

    /// What the toolbar item `element` holds, as its button on the bar - or in the menu behind it - shows it.
    func toolbarItemHolds(_ property: Prop, on element: MountedElement) throws -> HostValue?? {
        if let button = try barButtons().first(where: { $0.item === element }) {
            let e = button.node
            switch property {
            case .placement: return ToolbarItemPlacement.bar.propValue
            case .showsText: return try WebBrowser.truth("!e.querySelector('span').hidden", on: e).propValue
            case .text: return try WebBrowser.evaluate("e.getAttribute('aria-label')", on: e)?.propValue
            case .isEnabled: return try (!WebBrowser.truth("e.disabled", on: e)).propValue
            case .isDestructive: return try WebBrowser.truth("e.hasAttribute('data-destructive')", on: e).propValue
            case .accessibilityIdentifier: return .some(try WebBrowser.evaluate("e.dataset.identifier ?? null", on: e)?.propValue)
            case .icon: return .some(try picture("e.querySelector('img')", on: e))
            default: return nil
            }
        }
        guard property == .placement else { return nil }
        guard try behindTheBar(element) != nil else { return nil }
        press("Escape")
        return ToolbarItemPlacement.overflow.propValue
    }

    /// The bar as the user meets it: each edge's groups of actions, then those behind the bar's More.
    func bar(of page: MountedElement) throws -> String {
        guard let bar = renderer?.roster.controllers.first?.window.bar else { throw DriverCannot("read the bar of \(page.type.name)") }
        let buttons = bar.buttons.values
        let groups = { (edge: String) throws -> [[String]] in
            let script = "[...e.querySelectorAll('\(edge) > .stateui-bar-group')].map((g) => [...g.children]"
                + ".filter((b) => !b.hidden).map((b) => stateui.numberOf(b) + (b.disabled ? '!' : '')).join(',')).join(';')"
            let said = try WebBrowser.evaluate(script, on: bar.node) ?? ""
            return said.split(separator: ";").map { group in
                group.split(separator: ",").compactMap { word in
                    let enabled = !word.hasSuffix("!")
                    guard let node = Int32(word.filter(\.isNumber)),
                          let item = buttons.first(where: { $0.node == node })?.item else { return nil }
                    return BarWords.word(item, enabled: enabled)
                }
            }.filter { !$0.isEmpty }
        }
        let leading = try groups(".stateui-bar-start > .stateui-bar-actions")
        let trailing = try groups(":scope > .stateui-bar-actions")
        return BarWords.said(leading: leading, trailing: trailing, overflow: try overflow(of: page))
    }

    /// The actions behind the bar's More, as its menu shows them before the page's menus.
    private func overflow(of page: MountedElement) throws -> [String] {
        let bar = try self.bar(over: page)
        guard try WebBrowser.truth("!e.querySelector('button[aria-label=More]').hidden", on: bar) else { return [] }
        try click(bar, part: "button[aria-label=More]")
        defer { press("Escape") }
        let open = "[...document.querySelectorAll('.stateui-menu')].find((m) => m.matches(':popover-open'))"
        let script = "((m) => { const out = []; for (const c of m ? m.children : []) {"
            + " if (c.getAttribute('role') === 'separator') break; if (c.classList.contains('stateui-menu')) continue;"
            + " out.push((c.disabled ? '!' : '') + ([...c.querySelectorAll('span')].pop()?.textContent ?? '')); }"
            + " return out.join(String.fromCharCode(10)); })(\(open))"
        let said = try WebBrowser.evaluate(script, on: 0) ?? ""
        let items = toolbarItems(in: renderer?.runtime.tree.root)
        return said.split(separator: "\n").map { line in
            let enabled = !line.hasPrefix("!")
            let caption = String(enabled ? line : line.dropFirst())
            guard let item = items.first(where: { $0.value(.text)?.string == caption }) else { return String(line) }
            return BarWords.word(item, enabled: enabled)
        }
    }

    /// Every toolbar item under `element`, its slots included.
    private func toolbarItems(in element: MountedElement?) -> [MountedElement] {
        guard let element else { return [] }
        let own = element.type == .toolbarItem ? [element] : []
        return own + (element.children + element.slots).flatMap { toolbarItems(in: $0) }
    }

    /// The bar's actions, in their order on the page.
    func barButtons() throws -> [WebBarButton] {
        guard let bar = renderer?.roster.controllers.first?.window.bar else { return [] }
        let order = try numbers("[...e.querySelectorAll('.stateui-bar-group > button')].map(stateui.numberOf)", on: bar.node)
        let buttons = bar.buttons.values
        return order.compactMap { node in buttons.first { Double($0.node) == node } }
    }
}
