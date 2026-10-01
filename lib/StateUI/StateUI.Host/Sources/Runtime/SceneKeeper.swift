// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a host keeps of the application's scenes on a platform that restores no windows, the same on every such
/// host: at the start each scene it kept comes back with its values, and is offered the windows it had open; as the
/// scenes change they are kept again - but for the last scene's end, which leaves them as they stood for the next
/// start.
/// Design: docs/design/host/runtime.md#kept-scenes
@_spi(Host) @MainActor public final class SceneKeeper {
    /// Each standing scene's kept values, by the scene's key.
    private var values: [String: [String: HostValue]] = [:]

    /// The text kept last.
    private var kept: String?

    /// Nothing kept yet.
    public init() {}

    /// Brings back the scenes `kept` holds - one new scene where it holds none - each connected with its values
    /// before its first render, then offers each the windows it had open, each rendered before the next.
    public func restore(_ kept: KeptScenes, in runtime: HostRuntime) {
        let scenes = kept.scenes.isEmpty ? [KeptScenes.Scene()] : kept.scenes
        for scene in scenes { runtime.core.connectScene(restoring: scene.values) }
        runtime.pump.turn()

        for (scene, element) in zip(scenes, KeptScenes.scenes(of: runtime.tree.root)) {
            values[KeptScenes.key(of: element)] = scene.values
            guard let handler = element.handler(.windowRestored) else { continue }
            for window in scene.windows {
                let payload: [HostValue] = [.string(window.kind)] + (window.value.map { [.string($0)] } ?? [])
                runtime.pump.handlers.enqueuePhase(handler, payload: payload)
            }
        }
        runtime.pump.turn()
    }

    /// Keeps a scene's value as the act `persistSceneValue` carries it - the scene's key, the value's key, then the
    /// value; whether it was kept.
    @discardableResult
    public func keep(_ arguments: [HostValue]) -> Bool {
        guard arguments.count >= 3, let scene = arguments[0].name, let key = arguments[1].name else { return false }

        values[scene, default: [:]][key] = arguments[2]
        return true
    }

    /// The text to keep now that `root` holds its scenes as it does, where it differs from the text kept last; nil
    /// where it does not, and where no scene stands - the last scene's end keeps the scenes as they stood.
    public func changed(root: MountedElement?) -> String? {
        let standing = Set(KeptScenes.scenes(of: root).map(KeptScenes.key(of:)))
        guard !standing.isEmpty else { return nil }

        values = values.filter { standing.contains($0.key) }
        let text = KeptScenes(of: root, values: values).text
        guard text != kept else { return nil }
        kept = text
        return text
    }
}
