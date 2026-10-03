// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a host keeps of the application's scenes on a platform that restores no windows, the same on every such
/// host: at the start each window it kept comes back as its kind for its value, its scene's values landing where the
/// scene opens with it; as the scenes change they are kept again - but for the last scene's end, which leaves them
/// as they stood for the next start.
/// Design: docs/design/host/runtime.md#kept-scenes
@_spi(Host) @MainActor public final class SceneKeeper {
    /// Each standing scene's kept values, by the scene's key.
    private var values = SceneValues()

    /// The text kept last.
    private var kept: String?

    /// Nothing kept yet.
    public init() {}

    /// Brings back the windows `kept` holds, scene by scene, each connected as its kind for its value - where none
    /// comes back, the window launch opens - and renders them.
    public func restore(_ kept: KeptScenes, in runtime: HostRuntime) {
        var connected = false
        for scene in kept.scenes {
            for window in scene.windows {
                guard let key = runtime.connectWindow(
                    kind: window.kind, value: window.value, restoring: scene.values) else { continue }

                values.opened(key, keeping: scene.values)
                connected = true
            }
        }
        if !connected { runtime.connectWindow() }
        runtime.pump.turn()
    }

    /// Keeps a scene's value as the act `persistSceneValue` carries it - the scene's key, the value's key, then the
    /// value; whether it was kept.
    @discardableResult
    public func keep(_ arguments: [HostValue]) -> Bool {
        values.keep(arguments) != nil
    }

    /// The text to keep now that `root` holds its scenes as it does, where it differs from the text kept last; nil
    /// where it does not, and where no scene stands - the last scene's end keeps the scenes as they stood.
    public func changed(root: MountedElement?) -> String? {
        let standing = Set(SceneValues.scenes(of: root).map(SceneValues.key(of:)))
        guard !standing.isEmpty else { return nil }

        values.keep(only: standing)
        let text = KeptScenes(of: root, values: values).text
        guard text != kept else { return nil }
        kept = text
        return text
    }
}
