// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@_spi(Host) import StateUIConformance

/// The facts the WinUI driver reads besides a member: a menu as WinUI holds it, the keyboard, where a press lands,
/// the dialog showing, what the screen reader was told, what is drawn, the log, and what is kept.
extension WinUIDriver {
    func start(clock: TestClock?, application: @escaping @Sendable () -> any Application) throws -> MountedTree {
        written.listen()
        let renderer = WinUIRenderer.running(clock: clock, application: application)
        self.renderer = renderer
        return renderer.runtime.tree
    }

    func menu(of element: MountedElement) throws -> String {
        if element.type == .window { return try window().menuBar.menus }
        guard let view = (element.native as? WinUIElement)?.view else { throw DriverCannot("read the menu of \(element.type.name)") }
        return view.menus
    }

    func focused(_ element: MountedElement) throws -> Bool {
        guard let view = (element.native as? WinUIElement)?.view else { throw DriverCannot("read the focus of \(element.type.name)") }
        return stateui_winui_focused(view.handle)
    }

    func reaches(_ element: MountedElement, at point: Point) throws -> Bool {
        guard let view = (element.native as? WinUIElement)?.view else { throw DriverCannot("read what reaches \(element.type.name)") }
        renderer?.layOut()
        return view.reaches(point.x, point.y)
    }

    func question(over element: MountedElement) throws -> Question? {
        guard let content = try window().content else { return nil }
        return asked(over: content.handle).map { asked in
            Question(
                title: asked.title, message: asked.message,
                buttons: ([asked.accept, asked.cancel] + asked.choices).filter { !$0.isEmpty },
                field: asked.field)
        }
    }

    func announced() throws -> [String] {
        let length = stateui_winui_announced(nil, 0)
        var bytes = [CChar](repeating: 0, count: Int(length) + 1)
        _ = stateui_winui_announced(&bytes, Int32(bytes.count))
        let words = String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return words.isEmpty ? [] : words.split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
    }

    func color(of element: MountedElement, at point: Point) throws -> Color? {
        guard let view = (element.native as? WinUIElement)?.view else { throw DriverCannot("read the colour of \(element.type.name)") }
        // A shape or a picture renders only what it draws, from the first thing drawn; a layout renders whole from
        // its corner, so a point of any other view is read in the layout placing it, where StateUI placed the view.
        renderer?.layOut()
        let placing = view is WinUILayoutView ? nil : view.placingLayout
        let room = placing ?? view
        let place = placing.map { _ in (point.x + view.placedFrame.x, point.y + view.placedFrame.y) } ?? (point.x, point.y)
        guard let argb = room.pixels(at: [place]).first, argb >> 24 > 0x80 else { return nil }
        return Self.color(argb | 0xFF00_0000)
    }

    func logged() throws -> [String] {
        written.lines
    }

    func kept(_ key: String, inScene: Bool) throws -> HostValue? {
        if inScene { return WinUIPersistence.readScenes().scenes.first?.values[key] }
        let kept = WinUIPersistence.read()
        let kinds = [
            PersistentKey(key, of: String.self), PersistentKey(key, of: Double.self), PersistentKey(key, of: Int.self),
            PersistentKey(key, of: Bool.self),
        ]
        return kinds.lazy.compactMap { kept.restored(for: [$0])[key] }.first
    }

    /// The question showing over the window whose content is `content`, as WinUI's dialog holds it; nil for none.
    func asked(over content: StateUIObjectRef) -> WinUIAsked? {
        let length = stateui_winui_question(content, nil, 0)
        guard length >= 0 else { return nil }
        var bytes = [CChar](repeating: 0, count: Int(length) + 1)
        _ = stateui_winui_question(content, &bytes, Int32(bytes.count))
        let parts = String(decoding: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            .split(separator: "\u{1F}", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 5 else { return nil }
        return WinUIAsked(
            title: parts[0], message: parts[1], accept: parts[2], cancel: parts[3],
            field: parts[4] == "\u{01}" ? nil : parts[4], choices: Array(parts.dropFirst(5)))
    }

    /// The view whose menu holds a menu's item or a submenu - a view's context menu, or the window's bar - and its
    /// place among that menu's items, as WinUI chooses them.
    func menuPlace(of element: MountedElement) -> (owner: WinUIView, index: Int)? {
        var menu = element
        while let parent = menu.parent, parent.type != .contextMenu, parent.type != .page { menu = parent }
        guard let top = menu.parent else { return nil }
        let items = Self.flat(top).filter { $0.type == .menuItem }
        let index = items.firstIndex { $0 === element } ?? 0
        if top.type == .contextMenu, let owner = (top.parent?.native as? WinUIElement)?.view { return (owner, index) }
        guard let bar = renderer?.window?.menuBar else { return nil }
        return (bar, index)
    }

    /// `element` and everything under it, in the order a menu lists them.
    static func flat(_ element: MountedElement) -> [MountedElement] {
        element.children.flatMap { [$0] + flat($0) }
    }

    /// The place of `element` among the entries of its kind in its menu, in order.
    static func place(of element: MountedElement, among kind: NodeType) -> Int {
        var top = element
        while let parent = top.parent, parent.type != .contextMenu, parent.type != .page { top = parent }
        return flat(top.parent ?? top).filter { $0.type == kind }.firstIndex { $0 === element } ?? 0
    }

    /// A menu's entries as WinUI's reader writes them - "Copy;-;!Paste;Share[Mail]" - each by its caption, whether
    /// it can be chosen and whether it opens a submenu; separators left out.
    static func entries(of menu: String) -> [(caption: String, enabled: Bool, submenu: Bool)] {
        var entries: [(caption: String, enabled: Bool, submenu: Bool)] = []
        var word = ""
        func close(submenu: Bool) {
            guard !word.isEmpty, word != "-" else { word = ""; return }
            let enabled = !word.hasPrefix("!")
            entries.append((String(word.drop { $0 == "!" }), enabled, submenu))
            word = ""
        }
        for letter in menu {
            switch letter {
            case "[": close(submenu: true)
            case ";", "]": close(submenu: false)
            default: word.append(letter)
            }
        }
        close(submenu: false)
        return entries
    }
}

/// A question as WinUI's dialog holds it: its words, its buttons' captions and its field's words.
struct WinUIAsked {
    let title: String
    let message: String
    let accept: String
    let cancel: String
    let field: String?
    let choices: [String]
}

/// What the WinUI host wrote to its log while a driver listened, each line also printed.
final class WinUILogLines: @unchecked Sendable {
    private(set) var lines: [String] = []

    /// Listens to the host's log from now on.
    @MainActor func listen() {
        lines = []
        WinUIRenderer.log = HostLog(host: "WinUI") { [self] line in
            lines.append(line)
            print(line, terminator: "")
        }
    }
}
