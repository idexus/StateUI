// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scene as it runs - one session of the application: where it stands, and
/// what is done to its windows.
///
///     @Environment private var scene: SceneSession
///
///     Button("Fonts").onClicked { try await scene.openWindow(.fonts) }
///     Button("Document 7").onClicked { try await scene.openWindow(.document, value: 7) }
///     Label(scene.phase == .active ? "In front" : "Behind another window")
///
/// Every scene offers its own, so a view in one session acts on that session -
/// from a handler, an engine or a task alike, the session it holds saying
/// which. See `ApplicationSession` for what a session is.
public final class SceneSession {
    /// Where the scene stands right now. Starts `.active`: a scene being
    /// described is one being brought up.
    @State public internal(set) var phase: ScenePhase = .active

    /// The sessions of the scene's windows open right now: its main window's
    /// first, then the ones it opened beside it, in the order they opened -
    /// read like any state, so a view that shows them is built again as a
    /// window opens or closes. Nothing for a scene that has ended.
    ///
    ///     Label("\(scene.windows.count) windows")
    public var windows: [WindowSession] {
        guard let record = try? standing() else { return [] }

        return [record.windowSession(SceneElement.mainKey)]
            + record.windows.map { record.windowSession($0.key) }
    }

    /// The scene's number - what an inspector files the scene's renders
    /// under.
    let id: String

    /// The scene it is the session of - nothing for the one a view outside
    /// every scene reads, and nothing once that scene has ended.
    weak var record: SceneRecord?

    /// A scene's own, made by the scene it describes.
    init(id: String) {
        self.id = id
    }

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)` - one that is always in front and opens nothing.
    public convenience init() {
        self.init(id: "")
    }

    /// Opens the scene's window of a group that opens ONE.
    ///
    ///     Button("Fonts").onClicked { try await scene.openWindow(.fonts) }
    ///
    /// - Parameter type: the group's kind.
    /// - Throws: `WindowError.alreadyOpen` where it is open already, and the
    ///   rest of `WindowError` where the scene cannot open it.
    public nonisolated(nonsending) func openWindow(_ type: WindowType) async throws {
        try standing().open(type)
    }

    /// Opens the scene's window for a value.
    ///
    ///     Button("Open").onClicked { try await scene.openWindow(.document, value: id) }
    ///
    /// - Parameters:
    ///   - type: the group's kind.
    ///   - value: which value the window stands for.
    /// - Throws: `WindowError.alreadyOpen` where a window for that value is
    ///   open already, and the rest of `WindowError` where the scene cannot
    ///   open it.
    public nonisolated(nonsending) func openWindow<Value: Codable & Hashable>(
        _ type: WindowType,
        value: Value
    ) async throws {
        try standing().open(type, value: value)
    }

    /// Closes the scene's window of a group that opens ONE.
    ///
    /// - Parameter type: the group's kind.
    /// - Throws: `WindowError.notOpen` where it is not open, and
    ///   `WindowError.noScene` for a scene that has ended.
    public nonisolated(nonsending) func closeWindow(_ type: WindowType) async throws {
        try standing().close(type)
    }

    /// Closes the scene's window for a value.
    ///
    /// - Parameters:
    ///   - type: the group's kind.
    ///   - value: which value's window.
    /// - Throws: `WindowError.notOpen` where no window for that value is open,
    ///   and `WindowError.noScene` for a scene that has ended.
    public nonisolated(nonsending) func closeWindow<Value: Codable & Hashable>(
        _ type: WindowType,
        value: Value
    ) async throws {
        try standing().close(type, value: value)
    }

    /// Ends the session: its main window closes, and every window of it with
    /// it - what the user closing the main window does.
    ///
    /// - Throws: `WindowError.noScene` for a scene that has ended already, and
    ///   `WindowError.unsupported` where the platform opens no second window, a
    ///   phone's one window being the application's.
    public nonisolated(nonsending) func close() async throws {
        try Scenes.shared.close(standing())
    }

    /// The scene while the application still lists it; `WindowError.noScene`
    /// after it ended, whoever keeps its record alive.
    private func standing() throws -> SceneRecord {
        guard let record, Scenes.shared.record(id: record.id) === record else {
            throw WindowError.noScene
        }

        return record
    }
}
