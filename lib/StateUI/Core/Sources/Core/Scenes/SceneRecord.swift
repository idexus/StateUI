// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One scene standing: the windows it has open, what the platform kept for it, and the sessions it hands the views
/// under it.
@MainActor
final class SceneRecord {
    /// Its number - "1" for the first scene - which is also its key in the tree.
    let id: String

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

    /// What the platform kept for the scene's keys, by name.
    private var restored: [String: PropValue] = [:]

    /// The storage standing for each key - one key, one piece of state.
    private var keyed: [String: AnyObject] = [:]

    /// The keys written since the host last took them, each with its last value.
    private var waiting: [String: PropValue] = [:]

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
    func open(_ type: WindowType?, value: AnyHashable?, text: String?) {
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
    func close(_ type: WindowType, value: AnyHashable?) throws {
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
    func claim(_ name: String, orAdopt storage: AnyObject, landing land: (PropValue) -> Void) -> AnyObject {
        if let standing = keyed[name] { return standing }

        keyed[name] = storage

        if let held = restored[name] {
            land(held)
        }

        return storage
    }

    /// Marks a key as needing to be kept, replacing whatever value was
    /// waiting.
    func record(_ name: String, _ value: PropValue) {
        waiting[name] = value
    }

    /// How many keys are waiting to be kept.
    var pending: Int { waiting.count }

    /// The keys waiting to be kept, sorted by name, taken.
    func takeWaiting() -> [(name: String, value: PropValue)] {
        let taken = waiting.sorted { $0.key < $1.key }
        waiting.removeAll(keepingCapacity: true)
        return taken.map { (name: $0.key, value: $0.value) }
    }
}

/// A window a scene has open.
struct OpenedWindow: Equatable {
    /// Its kind; nil for a window of the group with no name.
    let type: WindowType?

    /// Its number in its scene, in opening order - what keeps it the same window when
    /// its value changes.
    let serial: Int

    /// The value it stands for, where its group opens one per value.
    var value: AnyHashable?

    /// That value written down, the way the platform keeps it.
    var text: String?

    /// What the tree knows it by: its kind - "window" for the group with no name - and its number.
    var key: String { "\(type?.name ?? "window") \(serial)" }
}

/// A state box a scene may keep - one declared with a `SceneKey`, which the
/// differ hands the scene it is built in.
@MainActor
protocol SceneClaiming: AnyObject {
    /// Pairs the box with the scene it is in: the storage the scene keeps
    /// under its key, and where its writes are kept.
    func claimScene(_ record: SceneRecord)
}
