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

    func place(of element: MountedElement) throws -> Rect {
        let view = try self.view(of: element, reading: .frame)
        let numbers = try numbers("stateui.box(e)", on: view.node)
        guard numbers.count == 4 else { throw DriverCannot("read where \(element.type.name) stands") }
        return Rect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
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

    /// What assistive technology was told, a few frames given for the page's live region to say it.
    func announced() throws -> [String] {
        for _ in 0..<10 where try words("stateui.announced", on: 0).isEmpty { WebBrowser.pause() }
        return try words("stateui.announced", on: 0)
    }

    func kept(_ key: String, inScene: Bool) throws -> HostValue? {
        guard !inScene else { throw DriverCannot("read what a scene keeps") }
        let words = try WebBrowser.evaluate("localStorage.getItem('StateUI kept values: Conformance')", on: 0) ?? ""
        let kept = KeptValuesText(words)
        let kinds = [
            PersistentKey(key, of: String.self), PersistentKey(key, of: Double.self), PersistentKey(key, of: Int.self),
            PersistentKey(key, of: Bool.self),
        ]
        return kinds.lazy.compactMap { kept.restored(for: [$0])[key] }.first
    }

    /// The bar's action of the toolbar item `element` chosen, as the user's click does.
    func chooseAction(_ element: MountedElement) throws {
        guard let button = try barButtons().first(where: { $0.item === element }) else {
            throw DriverCannot(.activate, on: element)
        }
        try click(button)
    }

    /// The bar's actions, in their order on the page.
    func barButtons() throws -> [WebBarButton] {
        guard let bar = renderer?.roster.controllers.first?.window.bar else { return [] }
        let order = try numbers("[...e.querySelectorAll('.stateui-bar-actions > button')].map(stateui.numberOf)", on: bar.node)
        let buttons = bar.buttons.values
        return order.compactMap { node in buttons.first { Double($0.node) == node } }
    }
}
