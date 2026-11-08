// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One scene standing: the windows it has open, what the platform kept for it, and the sessions it hands the views
/// under it.
@MainActor
final class SceneRecord {
    /// Its number - "1" for the first scene - its name in an act and in what is kept.
    let id: String

    /// Its key in the tree: its number behind StateUI's own separator.
    var key: String { OwnKey.scene(id) }

    /// Where its scene stands among those the application's body declares.
    var declaration: Int

    /// Its windows, in the order they opened.
    @State var windows: [OpenedWindow]

    /// Where the scene's inspector is docked - its place, and the window - nil where it is not.
    @State var dockedInspector: Inspector.Docking?

    /// Its session - what a view in the scene resolves as `SceneSession`.
    let session: SceneSession

    /// The last number given to one of its windows.
    private var serial: Int

    /// Each window's session, kept while the window is open.
    private var windowSessions: [String: WindowSession] = [:]

    /// What the platform kept for the scene's keys, by the name it keeps each under: a key claims its own by its name.
    private var restored: [String: PropValue] = [:]

    /// The storage standing for each key - one key, one piece of state.
    private var keyed: [KeyName: AnyObject] = [:]

    /// The keys written since the host last took them, each with its last value.
    private var waiting: [KeyName: PropValue] = [:]

    /// A scene, by its number, of declaration `declaration`, with `windows` open.
    init(id: String, declaration: Int, windows: [OpenedWindow] = []) {
        self.id = id
        self.declaration = declaration
        _windows = State(wrappedValue: windows)
        _dockedInspector = State(wrappedValue: nil)
        serial = windows.map(\.serial).max() ?? 0
        session = SceneSession(id: id)
        session.record = self
    }

    // MARK: - Its windows

    /// Opens a window of `type` - nil for the group with no name - for `value`, written `text`.
    func open(_ type: KeyName?, value: AnyHashable?, text: String?) {
        serial += 1
        windows.append(OpenedWindow(type: type, serial: serial, value: value, text: text))
    }

    /// Whether it holds the window `declaration` opens for `value` - a `Window` once, a group's window per value
    /// once, a group of no value never.
    func holds(_ declaration: DeclaredWindows, value: AnyHashable?) -> Bool {
        guard declaration.single || value != nil else { return false }

        return windows.contains { $0.type == declaration.type && $0.value == value }
    }

    /// Closes the window of `type` for `value` - every window of a group of no value - the scene ending with its
    /// last.
    func close(_ type: KeyName, value: AnyHashable?) throws {
        let closing = windows.filter { $0.type == type && $0.value == value }.map(\.key)
        guard !closing.isEmpty else { throw WindowError.notOpen }

        for key in closing { remove(key, ending: true) }
    }

    /// Closes one of its windows by its key - what that window's session asks for.
    func closeWindow(key: String) throws {
        guard windows.contains(where: { $0.key == key }) else { throw WindowError.notOpen }

        remove(key, ending: true)
    }

    /// The user closed one of its windows; a report about one already gone changes nothing.
    func closed(key: String) {
        guard windows.contains(where: { $0.key == key }) else { return }

        remove(key, ending: true)
    }

    /// Takes one of its windows out - the scene ending with its last, where `ending` says.
    /// Design: docs/design/core/scenes.md#a-scene-stands-once
    func remove(_ key: String, ending: Bool) {
        windows.removeAll { $0.key == key }

        if ending, windows.isEmpty { OpenScenes.shared.ended(self) }
    }

    /// Makes the window launch opens `window`, before anything has read the scene.
    func settle(_ window: OpenedWindow) {
        _windows.storage.value = [window]
        serial = window.serial
    }

    /// Makes one of its windows about another value - the window's own binding.
    func retarget<Value: Codable & Hashable>(_ serial: Int, to value: Value) {
        guard let index = windows.firstIndex(where: { $0.serial == serial }) else { return }

        windows[index].value = AnyHashable(value)
        windows[index].text = try? ValueText.write(value)
    }

    /// Why one of its windows may not be made about `value`: another window of its kind is open for it - one
    /// window of a kind per value, whoever writes, as opening one is refused; nil where it may.
    /// Design: docs/design/core/scenes.md#a-window-for-a-value
    func refusal<Value: Codable & Hashable>(of serial: Int, retargetingTo value: Value) -> String? {
        guard let window = windows.first(where: { $0.serial == serial }),
            windows.contains(where: { $0.serial != serial && $0.type == window.type && $0.value == AnyHashable(value) })
        else { return nil }

        return "The window `\(window.key)` was not made about \(value): a window of its kind is open for the "
            + "value \(value) already, and a kind has one window per value, whoever writes - as `openWindow` "
            + "refuses it. Close that window first, or write another value."
    }

    /// The state saying which value one of its windows is about, kept with the window's session: a write
    /// retargets the window, which is also what the platform restores it for, and a value another window of the
    /// kind is open for is refused.
    /// Design: docs/design/core/scenes.md#a-window-for-a-value
    func windowValue<Value: Codable & Hashable>(_ opened: OpenedWindow, as _: Value.Type) -> State<Value> {
        let session = windowSession(opened.key)
        if let standing = session.value as? State<Value> {
            return standing
        }

        // A window for a value opens only with one of its type, and is restored only with one that reads.
        guard let value = opened.value?.base as? Value else {
            preconditionFailure("a window for a value of \(Value.self) stands without one")
        }
        let made = State(wrappedValue: value)
        let serial = opened.serial
        made.storage.refuses = { [weak self] in self?.refusal(of: serial, retargetingTo: $0) }
        made.storage.keep = { [weak self] in self?.retarget(serial, to: $0) }
        session.value = made
        return made
    }

    /// The session of one of its windows, made once and kept.
    func windowSession(_ key: String) -> WindowSession {
        if let standing = windowSessions[key] {
            return standing
        }

        let made = WindowSession(key: key, record: self)
        windowSessions[key] = made
        return made
    }

    /// Lets go of the sessions of windows that have closed.
    func keepWindowSessions() {
        let open = Set(windows.map(\.key))

        windowSessions = windowSessions.filter { open.contains($0.key) }
    }

    // MARK: - What it keeps

    /// Takes what the platform kept for the scene's keys - before its first
    /// build, which is where the states claiming them are built.
    func restore(_ values: [String: PropValue]) {
        restored = values
    }

    /// The storage a key of this scene means: the one standing, or the offered one
    /// adopted, with what the platform kept landed in it.
    func claim(_ key: KeyName, orAdopt storage: AnyObject, landing land: (PropValue) -> Void) -> AnyObject {
        if let standing = keyed[key] { return standing }

        keyed[key] = storage

        if let held = restored[key.name] {
            land(held)
        }

        return storage
    }

    /// Marks a key as needing to be kept, replacing whatever value was waiting, and asks the host for a turn to
    /// take it.
    /// Design: docs/design/core/state.md#kept-state
    func record(_ key: KeyName, _ value: PropValue) {
        waiting[key] = value
        UIThreadExecutor.shared.askForTurn()
    }

    /// How many keys are waiting to be kept.
    var pending: Int { waiting.count }

    /// The keys waiting to be kept, sorted by name, taken.
    func takeWaiting() -> [(name: String, value: PropValue)] {
        let taken = waiting.sorted { $0.key < $1.key }
        waiting.removeAll(keepingCapacity: true)
        return taken.map { (name: $0.key.name, value: $0.value) }
    }
}

/// A window a scene has open.
struct OpenedWindow: Equatable {
    /// Its kind; nil for a window of the group with no name.
    let type: KeyName?

    /// Its number in its scene, in opening order - what keeps it the same window when
    /// its value changes.
    let serial: Int

    /// The value it stands for, where its group opens one per value.
    var value: AnyHashable?

    /// That value written down, the way the platform keeps it.
    var text: String?

    /// Its key in the tree: its kind - "window" for the group with no name - and its number, behind StateUI's own separator.
    var key: String { OwnKey.window(kind: type?.name, serial: serial) }
}

/// A state box a scene may keep - one declared with a `SceneKey`, which the
/// differ hands the scene it is built in.
@MainActor
protocol SceneClaiming: AnyObject {
    /// Pairs the box with the scene it is in: the storage the scene keeps
    /// under its key, and where its writes are kept.
    func claimScene(_ record: SceneRecord)
}
