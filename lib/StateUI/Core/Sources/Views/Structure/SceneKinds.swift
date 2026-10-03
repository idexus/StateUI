// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An application's kinds of scene as its `body` declares them, the first opening at launch. What
/// `ApplicationBuilder` makes of an application's body; nobody writes one.
public struct SceneKinds: Scene {
    /// Each kind's scene, in the order written.
    let scenes: [any Scene]

    /// None: the library's own scene.
    public var body: Never { return fatalError("SceneKinds is the library's own scene: it has no body") }
}

extension SceneKinds {
    /// What an application's body declares: its kinds, or the one scene a library test writes.
    static func of(_ body: any Scene) -> SceneKinds {
        body as? SceneKinds ?? SceneKinds(scenes: [body])
    }

    /// Each kind's main window - its type, nil for none, and whether the kind has one session - read without
    /// making anything a reader: a kind's name is fixed.
    /// Design: docs/design/core/scenes.md#kinds-of-scene
    var mains: [(type: WindowType?, oneSession: Bool)] {
        ReadScope.collect {
            scenes.map { scene in
                let windows = scene.declaredWindows
                return (windows.main.type, windows.oneSession)
            }
        }.value
    }

    /// Where `kind` stands among kinds whose main windows are of `types`: the first for `.first`; the unnamed one -
    /// the first where none is - for `.unnamed`; nil for a named kind none of them is.
    static func index(of kind: SceneKind, among types: [WindowType?]) -> Int? {
        switch kind {
        case .first: return types.isEmpty ? nil : 0
        case .unnamed: return types.firstIndex(of: nil) ?? (types.isEmpty ? nil : 0)
        case .named(let type): return types.firstIndex(of: type)
        }
    }

    /// The scene `record` is of, its kind settled on the record. A kind the application no longer declares - a
    /// scene the platform brought back - is the unnamed one, with nothing of what was kept.
    func scene(for record: SceneRecord) -> any Scene {
        let types = mains.map(\.type)
        var index = SceneKinds.index(of: record.kind, among: types)

        if index == nil {
            index = SceneKinds.index(of: .unnamed, among: types)
            record.restore([:])
        }

        let found = index ?? 0
        record.kind = SceneKind(main: types[found])
        return scenes[found]
    }
}
