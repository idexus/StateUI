// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scene as it runs: where it stands, and the windows it has open.
///
///     @Environment(\.scene) private var scene
///
///     Text(scene.phase == .active ? "In front" : "Behind another window")
///     Text("\(scene.windows.count) windows")
///
/// Every scene offers its own, so a view in one scene reads that scene - from a handler, an engine or a task alike,
/// the session it holds saying which. Its windows open through the application's session
/// (`ApplicationSession.openWindow`).
@MainActor
public final class SceneSession {
    /// Where the scene stands right now. Starts `.active`: a scene being
    /// described is one being brought up.
    @State public internal(set) var phase: ScenePhase = .active

    /// The sessions of the scene's windows open right now, in the order they opened - read like any state, so a
    /// view that shows them is built again as a window opens or closes. Nothing for a scene that has ended.
    ///
    ///     Text("\(scene.windows.count) windows")
    public var windows: [WindowSession] {
        guard let record = try? standing() else { return [] }

        return record.windows.map { record.windowSession($0.key) }
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

    /// Closes every window of the scene, ending it.
    ///
    /// - Throws: `WindowError.noScene` for a scene that has ended already, and `WindowError.unsupported` where the
    ///   platform opens no second window, a phone's one window being the application's.
    public func close() async throws {
        let record = try standing()
        guard OpenScenes.opensWindows else { throw WindowError.unsupported }

        OpenScenes.shared.ended(record)
    }

    /// The scene while the application still lists it; `WindowError.noScene`
    /// after it ended, whoever keeps its record alive.
    private func standing() throws -> SceneRecord {
        guard let record, OpenScenes.shared.record(id: record.id) === record else {
            throw WindowError.noScene
        }

        return record
    }
}
